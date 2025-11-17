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
	
	it "does not retain string references" do
		# Ruby 3.2 has different shared string behaviour:
		skip_unless_minimum_ruby_version("3.3")
		
		# Strings longer than 23 characters share a reference to a "shared" frozen string which should also be GC'd
		sampler.run do
			5.times do |i|
				short_text = "SHORT TEXT ##{i}"
				short_text.dup
				
				long_text = "LONG TEXT ##{i} 12345678901234567890123456789012345678901234567890"
				long_text.dup
				
				very_long_text = "VERY LONG TEXT ##{i} 12345678901234567890123456789012345678901234567890 12345678901234567890123456789012345678901234567890 12345678901234567890123456789012345678901234567890 12345678901234567890123456789012345678901234567890 12345678901234567890123456789012345678901234567890"
				very_long_text.dup
				
				# Prevent the last frozen string from being the return value of the block:
				nil
			end
		end
		
		# 30 strings should be allocated (5 iterations * 6 strings per iteration):
		# - short_text (interpolated result)
		# - short_text.dup
		# - long_text (interpolated result)
		# - long_text.dup
		# - very_long_text (interpolated result)
		# - very_long_text.dup
		expect(sampler.allocated.size).to be == 30
		
		# Get unique string values:
		string_allocations = sampler.allocated.select{|a| a.class_name == "String"}
		unique_strings = string_allocations.group_by(&:value).size
		
		# 15 unique strings (5 iterations * 3 unique strings per iteration):
		expect(unique_strings).to be == 15
		
		# No strings should be retained (all were eligible for GC):
		retained_strings = string_allocations.select(&:retained)
		expect(retained_strings.size).to be == 0
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
