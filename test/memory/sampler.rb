# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require "memory"

class MyThing
end

describe Memory::Sampler do
	let(:sampler) {subject.new}
	
	it "captures allocations" do
		sampler.run do
			MyThing.new
		end
		
		expect(sampler.allocated.size).to be == 1
		
		allocation = sampler.allocated.first
		expect(allocation.class_name).to be == MyThing.name
		expect(allocation.file).to be(:end_with?, "sampler.rb")
		expect(allocation.retained).to be_falsey
	end
	
	it "captures retained allocations" do
		x = nil
		
		sampler.run do
			x = MyThing.new
		end
		
		expect(sampler.allocated.size).to be == 1
		
		allocation = sampler.allocated.first
		expect(allocation.class_name).to be == MyThing.name
		expect(allocation.file).to be(:end_with?, "sampler.rb")
		expect(allocation.retained).to be_truthy
	end
end
