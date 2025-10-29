# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require_relative "usage"

module Memory
	# Aggregates memory allocations by a given metric.
	# Groups allocations and tracks totals for memory usage and allocation counts.
	class Aggregate
		# Initialize a new aggregate with a title and metric block.
		# @parameter title [String] The title for this aggregate.
		# @parameter block [Block] A block that extracts the metric from an allocation.
		def initialize(title, &block)
			@title = title
			@metric = block
			
			@total = Usage.new
			@totals = Hash.new{|h,k| h[k] = Usage.new}
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
			
			total << allocation
			@total << allocation
		end
		
		# Sort totals by a given key.
		# @parameter key [Symbol] The key to sort by (e.g., :size or :count).
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
			
			totals_by(:size).last(limit).reverse_each do |metric, total|
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
			
			@aggregates = Hash.new{|h,k| h[k] = Aggregate.new(safe_key(k.inspect), &@metric)}
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
			result = {
				title: @title,
				aggregates: @aggregates.map{|k, v| [safe_key(k), v.as_json]}
			}
		end
		
		private def safe_key(key)
			key.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
		end
	end
end
