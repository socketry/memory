# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2023, by Samuel Williams.

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
			
			def as_json(options = nil)
				{
					memory: memory,
					count: count
				}
			end
		end
		
		def initialize(title, &block)
			@title = title
			@metric = block
			
			@total = Total.new
			@totals = Hash.new{|h,k| h[k] = Total.new}
		end
		
		attr :title
		attr :metric
		attr :total
		attr :totals
		
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
		
		def as_json(options = nil)
			{
				title: @title,
				total: @total.as_json(options),
				totals: @totals.map{|k, v| [k, v.as_json(options)]}
			}
		end
	end
	
	class ValueAggregate
		def initialize(title, &block)
			@title = title
			@metric = block
			
			@aggregates = Hash.new{|h,k| h[k] = Aggregate.new(k.inspect, &@metric)}
		end
		
		attr :title
		attr :metric
		attr :aggregates
		
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
		
		def as_json(options = nil)
			{
				title: @title,
				aggregates: @aggregates.map{|k, v| [k, v.as_json]}
			}
		end
	end
end
