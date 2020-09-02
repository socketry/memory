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
	end
end
