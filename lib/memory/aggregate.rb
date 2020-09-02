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

module Memory
	UNITS = {
		0 => 'B',
		3 => 'KiB',
		6 => 'MiB',
		9 => 'GiB',
		12 => 'TiB',
		15 => 'PiB',
		18 => 'EiB',
		21 => 'ZiB',
		24 => 'YiB'
	}.freeze
	
	def self.formatted_bytes(bytes)
		return "0 B" if bytes.zero?
		
		scale = Math.log2(bytes).div(10) * 3
		scale = 24 if scale > 24
		"%.2f #{UNITS[scale]}" % (bytes / 10.0**scale)
	end
	
	class Aggregate
		Total = Struct.new(:memory, :count) do
			def initialize
				super(0, 0)
			end
			
			def << allocation
				self.memory += allocation.size
				self.count += 1
			end
			
			def formatted_memory
				self.memory
			end
			
			def to_s
				"(#{Memory.formatted_bytes memory} in #{count} allocations)"
			end
		end
		
		def initialize(title, &block)
			@title = title
			@metric = block
			
			@total = Total.new
			@totals = Hash.new{|h,k| h[k] = Total.new}
		end
		
		attr :total
		
		def << allocation
			metric = @metric.call(allocation)
			total = @totals[metric]
			
			total.memory += allocation.memsize
			total.count += 1
			
			@total.memory += allocation.memsize
			@total.count += 1
		end
		
		def totals_by(key)
			@totals.sort_by{|metric, total| [total[key], metric]}
		end
		
		def print(io = $stderr, limit: 10, title: @title, level: 2)
			io.puts "#{'#' * level} #{title} #{@total}", nil
			
			totals_by(:memory).last(limit).reverse_each do |metric, total|
				io.puts "- #{total}\t#{metric}"
			end
			
			io.puts nil
		end
	end
	
	class ValueAggregate
		def initialize(title, &block)
			@title = title
			@metric = block
			
			@aggregates = Hash.new{|h,k| h[k] = Aggregate.new(k.inspect, &@metric)}
		end
		
		def << allocation
			if value = allocation.value
				aggregate = @aggregates[value]
				
				aggregate << allocation
			end
		end
		
		def aggregates_by(key)
			@aggregates.sort_by{|value, aggregate| [aggregate.total[key], value]}
		end
		
		def print(io = $stderr, limit: 10, level: 2)
			io.puts "#{'#' * level} #{@title}", nil
			
			aggregates_by(:count).last(limit).reverse_each do |value, aggregate|
				aggregate.print(io, level: level+1)
			end
		end
	end
end
