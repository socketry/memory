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
	
	it "safely captures locked string objects" do
		fiber = Fiber.new do |string|
			IO::Buffer.for(string) do
				# string is now locked for the duration of this block.
				sleep(0.1)
				Fiber.yield
			end
		end
		
		memory = Memory::Sampler.new
		memory.start
		
		# Lock the string
		key = String.new("foo")
		fiber.resume(key)
		
		memory.stop
		memory.report # buffer string is locked while reading ObjectSpace#each_object
	end
	
	with "#as_json" do
		it "returns allocation count" do
			x = nil
			
			sampler.run do
				x = MyThing.new
			end
			
			json_data = sampler.as_json
			
			expect(json_data).to have_keys(:allocations)
			expect(json_data[:allocations]).to be > 0
		end
	end
	
	with "#to_json" do
		it "produces valid JSON string" do
			x = nil
			
			sampler.run do
				x = MyThing.new
			end
			
			json_string = sampler.to_json
			parsed = JSON.parse(json_string)
			
			expect(parsed["allocations"]).to be > 0
		end
	end
end
