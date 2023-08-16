# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2022, by Samuel Williams.

require_relative 'aggregate'

module Memory
	class Report
		def self.general
			Report.new([
				Aggregate.new("By Gem", &:gem),
				Aggregate.new("By File", &:file),
				Aggregate.new("By Location", &:location),
				Aggregate.new("By Class", &:class_name),
				ValueAggregate.new("Strings By Gem", &:gem),
				ValueAggregate.new("Strings By Location", &:location),
			])
		end
		
		def initialize(aggregates)
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
				@total_retained << allocation if allocation.retained
				
				@aggregates.each do |aggregate|
					aggregate << allocation
				end
			end
		end
		
		def print(io = $stderr)
			io.puts "\# Memory Profile", nil
			
			io.puts "- Total Allocated: #{@total_allocated}"
			io.puts "- Total Retained: #{@total_retained}"
			io.puts
			
			@aggregates.each do |aggregate|
				aggregate.print(io)
			end
		end
		
		def as_json(options = nil)
			{
				total_allocated: @total_allocated.as_json(options),
				total_retained: @total_retained.as_json(options),
				aggregates: @aggregates.map{|aggregate| aggregate.as_json(options)}
			}
		end
		
		def to_json(...)
			as_json.to_json(...)
		end
	end
end
