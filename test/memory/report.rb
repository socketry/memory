# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2023, by Samuel Williams.

require "memory"

describe Memory::Report do
	let(:report) do
		Memory.report do
			Array.new
			"Hello World".dup
		end
	end
	
	it "accepts options" do
		result = report.as_json(max_nesting: 1)
	end
	
	it "captures allocations" do
		result = report.as_json
		
		expect(result).to have_keys(
			total_allocated: be_a(Hash),
			total_retained: be_a(Hash),
			aggregates: be_a(Array),
		)
		
		expect(result[:total_allocated]).to have_keys(
			memory: be_a(Integer),
			count: be_a(Integer),
		)
		
		expect(result[:total_retained]).to have_keys(
			memory: be_a(Integer),
			count: be_a(Integer),
		)
		
		expect(result[:aggregates]).to have_attributes(size: be == 6)
	end
	
	with "custom report" do
		let(:report) do
			Memory::Report.new([
				Memory::Aggregate.new("By Gem", &:gem),
				Memory::Aggregate.new("By File", &:file),
				Memory::Aggregate.new("By Class", &:class_name),
			])
		end
		
		it "captures allocations" do
			Memory.capture(report) do
				Array.new
			end
			
			expect(report.aggregates).to have_attributes(size: be == 3)
		end
	end
end
