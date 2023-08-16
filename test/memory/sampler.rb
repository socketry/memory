# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2023, by Samuel Williams.

require 'memory'

describe Memory::Sampler do
	let(:sampler) {subject.new}
	
	it "captures allocations" do
		sampler.run do
			Array.new
		end
		
		expect(sampler.allocated.size).to be == 1
		
		allocation = sampler.allocated.first
		expect(allocation.class_name).to be == "Array"
		expect(allocation.file).to be(:end_with?, "sampler.rb")
		expect(allocation.retained).to be == false
	end
	
	it "captures retained allocations" do
		x = nil
		
		sampler.run do
			x = Array.new
		end
		
		expect(sampler.allocated.size).to be == 1
		
		allocation = sampler.allocated.first
		expect(allocation.class_name).to be == "Array"
		expect(allocation.file).to be(:end_with?, "sampler.rb")
		expect(allocation.retained).to be == true
	end
end
