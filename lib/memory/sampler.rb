# frozen_string_literal: true

# Copyright, 2020, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'objspace'
require 'msgpack'
require 'console'

module Memory
	class Wrapper < MessagePack::Factory
		def initialize(cache)
			super()
			
			@cache = cache
			
			self.register_type(0x01, Allocation,
				packer: ->(instance){self.pack(instance.pack)},
				unpacker: ->(data){Allocation.unpack(@cache, self.unpack(data))},
			)
			
			self.register_type(0x02, Symbol)
		end
	end
	
	Allocation = Struct.new(:cache, :class_name, :file, :line, :memsize, :value, :retained) do
		def location
			cache.lookup_location(file, line)
		end
		
		def gem
			cache.guess_gem(file)
		end
		
		def pack
			[class_name, file, line, memsize, value, retained]
		end
		
		def self.unpack(cache, fields)
			self.new(cache, *fields)
		end
	end
	
	# Sample memory allocations.
	#
	# ~~~ ruby
	# sampler = Sampler.capture do
	# 	5.times { "foo" }
	# end
	# ~~~
	class Sampler
		def initialize(&filter)
			@filter = filter
			
			@cache = Cache.new
			@wrapper = Wrapper.new(@cache)
			@allocated = Array.new
		end
		
		attr :filter
		
		attr :cache
		attr :wrapper
		attr :allocated
		
		def start
			GC.disable
			GC.start
			
			@generation = GC.count
			ObjectSpace.trace_object_allocations_start
		end
		
		def stop
			ObjectSpace.trace_object_allocations_stop
			allocated = track_allocations(@generation)
			
			Console.logger.debug(self, "Got allocated list: #{allocated.size}, Allocated object count: #{ObjectSpace.count_objects.inspect}")
			
			GC.enable
			3.times{GC.start}
			
			Console.logger.debug(self, "Retained object count: #{ObjectSpace.count_objects.inspect}")
			
			# Caution: Do not allocate any new Objects between the call to GC.start and the completion of the retained lookups. It is likely that a new Object would reuse an object_id from a GC'd object.
			
			ObjectSpace.each_object do |obj|
				next unless ObjectSpace.allocation_generation(obj) == @generation
				
				if found = allocated[obj.__id__]
					found.retained = true
				end
			end
			
			ObjectSpace.trace_object_allocations_clear
		end
		
		def dump(io = nil)
			Console.logger.debug(self, "Dumping allocations: #{@allocated.size}")
			
			if io
				packer = @wrapper.packer(io)
				packer.pack(@allocated)
				packer.flush
			else
				@wrapper.dump(@allocated)
			end
		end
		
		def load(data)
			allocations = @wrapper.load(data)
			
			Console.logger.debug(self, "Loading allocations: #{allocations.size}")
			
			@allocated.concat(allocations)
		end
		
		def report
			report = Report.general
			
			report.concat(@allocated)
			
			return report
		end
		
		# Collects object allocation and memory of ruby code inside of passed block.
		def run(&block)
			start
			
			begin
				# We do this to avoid retaining the result of the block.
				yield && nil
			ensure
				stop
			end
		end
		
		private
		
		# Iterates through objects in memory of a given generation.
		# Stores results along with meta data of objects collected.
		def track_allocations(generation)
			rvalue_size = GC::INTERNAL_CONSTANTS[:RVALUE_SIZE]
			
			allocated = Hash.new.compare_by_identity
			
			ObjectSpace.each_object do |obj|
				next unless ObjectSpace.allocation_generation(obj) == generation
				
				file = ObjectSpace.allocation_sourcefile(obj) || "(no name)"
				
				klass = obj.class rescue nil
				
				unless Class === klass
					# attempt to determine the true Class when .class returns something other than a Class
					klass = Kernel.instance_method(:class).bind(obj).call
				end
				
				next if @filter && !@filter.call(klass, file)
				
				line = ObjectSpace.allocation_sourceline(obj)
				
				# we do memsize first to avoid freezing as a side effect and shifting
				# storage to the new frozen string, this happens on @hash[s] in lookup_string
				memsize = ObjectSpace.memsize_of(obj)
				class_name = @cache.lookup_class_name(klass)
				value = (klass == String) ? @cache.lookup_string(obj) : nil
				
				# compensate for API bug
				memsize = rvalue_size if memsize > 100_000_000_000
				
				allocation = Allocation.new(@cache, class_name, file, line, memsize, value, false)
				
				@allocated << allocation
				allocated[obj.__id__] = allocation
			end
			
			return allocated
		end
	end
end
