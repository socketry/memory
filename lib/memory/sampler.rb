# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2013-2020, by Sam Saffron.
# Copyright, 2014, by Richard Schneeman.
# Copyright, 2014, by Søren Skovsbøll.
# Copyright, 2015, by Anton Davydov.
# Copyright, 2015-2018, by Dave Gynn.
# Copyright, 2017, by Nick LaMuro.
# Copyright, 2018, by William Tabi.
# Copyright, 2018, by Jonas Peschla.
# Copyright, 2018, by Espartaco Palma.
# Copyright, 2020, by Jean Boussier.
# Copyright, 2020-2025, by Samuel Williams.

require "objspace"
require "msgpack"
require "json"
require "console"

require_relative "cache"

module Memory
	# MessagePack factory wrapper for serializing allocations.
	# Registers custom types for efficient serialization of allocation data.
	class Wrapper < MessagePack::Factory
		# Initialize the wrapper with a cache.
		# @parameter cache [Cache] The cache to use for allocation metadata.
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
		# Load allocations from an ObjectSpace heap dump.
		#
		# If a block is given, it will be called periodically with progress information.
		#
		# @parameter io [IO] The IO stream containing the heap dump JSON.
		# @yields [line_count, object_count] Progress callback with current line and object counts.
		# @returns [Sampler] A new sampler populated with allocations from the heap dump.
		def self.load_object_space_dump(io, &block)
			sampler = new
			cache = sampler.cache
			
			line_count = 0
			object_count = 0
			report_interval = 10000
			
			io.each_line do |line|
				line_count += 1
				
				begin
					object = JSON.parse(line)
				rescue JSON::ParserError
					# Skip invalid JSON lines
					next
				end
				
				# Skip non-object entries (ROOT, SHAPE, etc.)
				next unless object["address"]
				
				# Get allocation information (may be nil if tracing wasn't enabled)
				file = object["file"] || "(unknown)"
				line_number = object["line"] || 0
				
				# Get object type/class
				type = object["type"] || "unknown"
				
				# Get memory size
				memsize = object["memsize"] || 0
				
				# Get value for strings
				value = object["value"]
				
				allocation = Allocation.new(
					cache,
					type,           # class_name
					file,           # file
					line_number,    # line
					memsize,        # memsize
					value,          # value (for strings)
					true            # retained (all objects in heap dump are live)
				)
				
				sampler.allocated << allocation
				object_count += 1
				
				# Report progress periodically
				if block && (object_count % report_interval == 0)
					block.call(line_count, object_count)
				end
			end
			
			# Final progress report
			block.call(line_count, object_count) if block
			
			return sampler
		end
		
		# Initialize a new sampler.
		# @parameter filter [Block | Nil] Optional filter block to select which allocations to track.
		def initialize(&filter)
			@filter = filter
			
			@cache = Cache.new
			@wrapper = Wrapper.new(@cache)
			@allocated = Array.new
		end
		
		# Generate a human-readable representation of this sampler.
		# @returns [String] String showing the number of allocations tracked.
		def inspect
			"#<#{self.class} #{@allocated.size} allocations>"
		end
		
		attr :filter
		
		attr :cache
		attr :wrapper
		attr :allocated
		
		# Start tracking memory allocations.
		# Disables GC and begins ObjectSpace allocation tracing.
		def start
			GC.disable
			3.times{GC.start}
			
			# Ensure any allocations related to the block are freed:
			GC.start
			
			@generation = GC.count
			ObjectSpace.trace_object_allocations_start
		end
		
		# Stop tracking allocations and determine which ones were retained.
		# Re-enables GC and marks retained allocations.
		def stop
			ObjectSpace.trace_object_allocations_stop
			allocated = track_allocations(@generation)
			
			# **WARNING** Do not allocate any new Objects between the call to GC.start and the completion of the retained lookups. It is likely that a new Object would reuse an object_id from a GC'd object.
			
			# Overwrite any immediate values on the C stack to avoid retaining them.
			ObjectSpace.dump(Object.new)
			
			GC.enable
			3.times{GC.start}
			
			# See above.
			GC.start
			
			ObjectSpace.each_object do |object|
				next unless ObjectSpace.allocation_generation(object) == @generation
				
				if found = allocated[object.__id__]
					found.retained = true
				end
			end
			
			ObjectSpace.trace_object_allocations_clear
		end
		
		# Serialize allocations to MessagePack format.
		# @parameter io [IO | Nil] Optional IO stream to write to. If nil, returns serialized data.
		# @returns [String | Nil] Serialized data if no IO stream provided, otherwise nil.
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
		
		# Load allocations from MessagePack-serialized data.
		# @parameter data [String] The serialized allocation data.
		def load(data)
			allocations = @wrapper.load(data)
			
			Console.logger.debug(self, "Loading allocations: #{allocations.size}")
			
			@allocated.concat(allocations)
		end
		
		# Generate a report from the tracked allocations.
		# @parameter options [Hash] Options to pass to the report constructor.
		# @returns [Report] A report containing allocation statistics.
		def report(**options)
			report = Report.general(**options)
			
			report.concat(@allocated)
			
			return report
		end
		
		# Convert this sampler to a JSON-compatible summary.
		# Returns the allocation count without iterating through all allocations.
		# @parameter options [Hash | Nil] Optional JSON serialization options.
		# @returns [Hash] JSON-compatible summary of sampler data.
		def as_json(options = nil)
			{
				allocations: @allocated.size
			}
		end
		
		# Convert this sampler to a JSON string.
		# @returns [String] JSON representation of this sampler summary.
		def to_json(...)
			as_json.to_json(...)
		end
		
		# Collects object allocation and memory of ruby code inside of passed block.
		def run(&block)
			start
			
			begin
				# We do this to avoid retaining the result of the block.
				yield && false
			ensure
				stop
			end
		end
		
		private
		
		# Iterates through objects in memory of a given generation.
		# Stores results along with meta data of objects collected.
		def track_allocations(generation)
			rvalue_size = GC::INTERNAL_CONSTANTS[:RVALUE_SIZE]
			
			allocated = Hash.new
			
			ObjectSpace.each_object do |object|
				next unless ObjectSpace.allocation_generation(object) == generation
				
				file = ObjectSpace.allocation_sourcefile(object) || "(no name)"
				
				klass = object.class rescue nil
				
				unless Class === klass
					# attempt to determine the true Class when .class returns something other than a Class
					klass = Kernel.instance_method(:class).bind(object).call
				end
				
				next if @filter && !@filter.call(klass, file)
				
				line = ObjectSpace.allocation_sourceline(object)
				
				# we do memsize first to avoid freezing as a side effect and shifting
				# storage to the new frozen string, this happens on @hash[s] in lookup_string
				memsize = ObjectSpace.memsize_of(object)
				class_name = @cache.lookup_class_name(klass)
				value = (klass == String) ? @cache.lookup_string(object) : nil
				
				# compensate for API bug
				memsize = rvalue_size if memsize > 100_000_000_000
				
				allocation = Allocation.new(@cache, class_name, file, line, memsize, value, false)
				
				@allocated << allocation
				allocated[object.__id__] = allocation
			end
			
			return allocated
		end
	end
end
