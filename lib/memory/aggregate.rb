# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

module Memory
	UNITS = {
		0 => "B",
		3 => "KiB",
		6 => "MiB",
		9 => "GiB",
		12 => "TiB",
		15 => "PiB",
		18 => "EiB",
		21 => "ZiB",
		24 => "YiB"
	}.freeze
	
	# Format bytes into human-readable units.
	# @parameter bytes [Integer] The number of bytes to format.
	# @returns [String] Formatted string with appropriate unit (e.g., "1.50 MiB").
	def self.formatted_bytes(bytes)
		return "0 B" if bytes.zero?
		
		scale = Math.log2(bytes).div(10) * 3
		scale = 24 if scale > 24
		"%.2f #{UNITS[scale]}" % (bytes / 10.0**scale)
	end
	
	# Aggregates memory allocations by a given metric.
	# Groups allocations and tracks totals for memory usage and allocation counts.
	class Aggregate
		Total = Struct.new(:memory, :count) do
			def initialize
				super(0, 0)
			end
			
			def << allocation
				self.memory += allocation.memsize
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
		
		# Initialize a new aggregate with a title and metric block.
		# @parameter title [String] The title for this aggregate.
		# @parameter block [Block] A block that extracts the metric from an allocation.
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
		
		# Add an allocation to this aggregate.
		# @parameter allocation [Allocation] The allocation to add.
		def << allocation
			metric = @metric.call(allocation)
			total = @totals[metric]
			
			total.memory += allocation.memsize
			total.count += 1
			
			@total.memory += allocation.memsize
			@total.count += 1
		end
		
		# Sort totals by a given key.
		# @parameter key [Symbol] The key to sort by (e.g., :memory or :count).
		# @returns [Array] Sorted array of [metric, total] pairs.
		def totals_by(key)
			@totals.sort_by{|metric, total| [total[key], metric]}
		end
		
		# Print this aggregate to an IO stream.
		# @parameter io [IO] The output stream to write to.
		# @parameter limit [Integer] Maximum number of items to display.
		# @parameter title [String] Optional title override.
		# @parameter level [Integer] Markdown heading level for output.
		def print(io = $stderr, limit: 10, title: @title, level: 2)
			io.puts "#{'#' * level} #{title} #{@total}", nil
			
			totals_by(:memory).last(limit).reverse_each do |metric, total|
				io.puts "- #{total}\t#{metric}"
			end
			
			io.puts nil
		end
		
		# Convert this aggregate to a JSON-compatible hash.
		# @parameter options [Hash | Nil] Optional JSON serialization options.
		# @returns [Hash] JSON-compatible representation.
		def as_json(options = nil)
			{
				title: @title,
				total: @total.as_json(options),
				totals: @totals.map{|k, v| [k, v.as_json(options)]}
			}
		end
	end
	
	# Aggregates memory allocations by value.
	# Groups allocations by their actual values (e.g., string contents) and creates sub-aggregates.
	class ValueAggregate
		# Initialize a new value aggregate.
		# @parameter title [String] The title for this aggregate.
		# @parameter block [Block] A block that extracts the metric from an allocation.
		def initialize(title, &block)
			@title = title
			@metric = block
			
			@aggregates = Hash.new{|h,k| h[k] = Aggregate.new(k.inspect, &@metric)}
		end
		
		attr :title
		attr :metric
		attr :aggregates
		
		# Add an allocation to this value aggregate.
		# @parameter allocation [Allocation] The allocation to add.
		def << allocation
			if value = allocation.value
				aggregate = @aggregates[value]
				
				aggregate << allocation
			end
		end
		
		# Sort aggregates by a given key.
		# @parameter key [Symbol] The key to sort by (e.g., :memory or :count).
		# @returns [Array] Sorted array of [value, aggregate] pairs.
		def aggregates_by(key)
			@aggregates.sort_by{|value, aggregate| [aggregate.total[key], value]}
		end
		
		# Print this value aggregate to an IO stream.
		# @parameter io [IO] The output stream to write to.
		# @parameter limit [Integer] Maximum number of items to display.
		# @parameter level [Integer] Markdown heading level for output.
		def print(io = $stderr, limit: 10, level: 2)
			io.puts "#{'#' * level} #{@title}", nil
			
			aggregates_by(:count).last(limit).reverse_each do |value, aggregate|
				aggregate.print(io, level: level+1)
			end
		end
		
		# Convert this value aggregate to a JSON-compatible hash.
		# @parameter options [Hash | Nil] Optional JSON serialization options.
		# @returns [Hash] JSON-compatible representation.
		def as_json(options = nil)
			{
				title: @title,
				aggregates: @aggregates.map{|k, v| [k, v.as_json]}
			}
		end
	end
end
