# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

require 'memory'

describe Memory::Report do
	let(:report) do
		Memory.report do |report|
			Array.new
			"Hello World".dup
		end
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
end
