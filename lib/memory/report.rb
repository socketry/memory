# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require_relative "aggregate"

module Memory
	# A report containing aggregated memory allocation statistics.
	# Collects and organizes allocation data by various metrics.
	class Report
		# Create a general-purpose report with standard aggregates.
		# @parameter options [Hash] Options to pass to the report constructor.
		# @returns [Report] A new report with standard aggregates.
		def self.general(**options)
			Report.new([
				Aggregate.new("By Gem", &:gem),
				Aggregate.new("By File", &:file),
				Aggregate.new("By Location", &:location),
				Aggregate.new("By Class", &:class_name),
				ValueAggregate.new("Strings By Gem", &:gem),
				ValueAggregate.new("Strings By Location", &:location),
			], **options)
		end
		
		# Initialize a new report with the given aggregates.
		# @parameter aggregates [Array] Array of Aggregate or ValueAggregate instances.
		# @parameter retained_only [Boolean] Whether to only include retained allocations in aggregates.
		def initialize(aggregates, retained_only: true)
			@retained_only = retained_only
			
			@total_allocated = Aggregate::Total.new
			@total_retained = Aggregate::Total.new
			
			@aggregates = aggregates
		end
		
		attr :total_allocated
		attr :total_retained
		attr :aggregates
		
		# Add all samples from the given sampler to this report.
		def add(sampler)
			self.concat(sampler.allocated)
		end
		
		# Add allocations to this report.
		def concat(allocations)
			allocations.each do |allocation|
				@total_allocated << allocation
				
				if allocation.retained
					@total_retained << allocation
				end
				
				if !@retained_only || allocation.retained
					@aggregates.each do |aggregate|
						aggregate << allocation
					end
				end
			end
		end
		
		# Print this report to an IO stream.
		# @parameter io [IO] The output stream to write to.
		def print(io = $stderr)
			if @retained_only
				io.puts "\# Retained Memory Profile", nil
			else
				io.puts "\# Memory Profile", nil
			end
			
			io.puts "- Total Allocated: #{@total_allocated}"
			io.puts "- Total Retained: #{@total_retained}"
			io.puts
			
			@aggregates.each do |aggregate|
				aggregate.print(io)
			end
		end
		
		# Convert this report to a JSON-compatible hash.
		# @parameter options [Hash | Nil] Optional JSON serialization options.
		# @returns [Hash] JSON-compatible representation.
		def as_json(options = nil)
			{
				total_allocated: @total_allocated.as_json(options),
				total_retained: @total_retained.as_json(options),
				aggregates: @aggregates.map{|aggregate| aggregate.as_json(options)}
			}
		end
		
		# Convert this report to a JSON string.
		# @returns [String] JSON representation of this report.
		def to_json(...)
			as_json.to_json(...)
		end
		
		# Generate a human-readable representation of this report.
		# @returns [String] Summary showing allocated and retained totals.
		def inspect
			"#<#{self.class}: #{@total_allocated} allocated, #{@total_retained} retained>"
		end
	end
end
