# frozen_string_literal: true

module MemoryProfiler
	class Aggregate
		Total = Struct.new(:memory, :count)
		
		def initialize(&block)
			@metric = block
			
			@totals = Hash.new{|h,k| h[k] = Total.new}
		end
		
		def concat(values)
			values.group_by(&@metric).each do |metric, allocations|
				total = @totals[metric]
				total.memory += allocations.sum(&:memsize)
				total.count += allocations.size
			end
		end
		
		def by_memory
			@totals.sort_by{|metric, total| [-total.memory, metric]}
		end
		
		def by_count
			@totals.sort_by{|metric, total| [-total.count, metric]}
		end
	end

	class Report
		def initialize(aggregates)
			@aggregates = aggregates
		end
		
		def 
end
