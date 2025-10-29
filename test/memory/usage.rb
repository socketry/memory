# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2025, by Samuel Williams.

require "memory/usage"

describe Memory::Usage do
	let(:usage) {subject.new}
	
	it "is zero by default" do
		expect(usage).to have_attributes(
			size: be == 0,
			count: be == 0
		)
	end
	
	with "#<<" do
		it "can accumulate usage" do
			other = subject.new(100, 1)
			
			3.times do
				usage << other
			end
			
			expect(usage).to have_attributes(
				size: be == 300,
				count: be == 3
			)
		end
	end
	
	with ".of" do
		it "can compute usage of an object" do
			object = Object.new
			usage = subject.of(object)
			expect(usage).to have_attributes(
				size: be > 0,
				count: be == 1
			)
		end

		it "can compute size of nested objects" do
			object = [Object.new, Object.new]
			usage = subject.of(object)
			expect(usage).to have_attributes(
				size: be > 40,
				count: be == 3
			)
		end
		
		it "skips modules in object graph" do
			object = [Object.new, String]
			usage = subject.of(object)
			# Should count array and one object, but not String (which is a Module)
			expect(usage).to have_attributes(
				count: be == 2
			)
		end
		
		it "handles circular references without infinite loop" do
			array = []
			array << array # Circular reference.
			usage = subject.of(array)
			
			# Should count the array exactly once:
			expect(usage).to have_attributes(
				count: be == 1,
				size: be > 0
			)
		end
		
		it "counts shared objects only once" do
			shared = Object.new
			array = [shared, shared, shared]
			usage = subject.of(array)
			# Should count array + shared object = 2 objects:
			expect(usage).to have_attributes(
				count: be == 2
			)
		end
		
		it "can compute usage of hash with objects" do
			hash = {key: Object.new, another: Object.new}
			usage = subject.of(hash)
			# Hash + 2 objects + 2 symbols (keys):
			expect(usage).to have_attributes(
				size: be > 0,
				count: be >= 3 # At least hash and 2 objects.
			)
		end
		
		it "can compute usage of objects with instance variables" do
			object = Object.new
			object.instance_variable_set(:@data, Object.new)
			object.instance_variable_set(:@more, Object.new)
			
			usage = subject.of(object)
			# Should count root object + 2 instance variable objects:
			expect(usage).to have_attributes(
				count: be == 3,
				size: be > 0
			)
		end
		
		it "handles deeply nested structures" do
			deep = [[[[Object.new]]]]
			usage = subject.of(deep)
			# 4 arrays + 1 object = 5 objects:
			expect(usage).to have_attributes(
				count: be == 5,
				size: be > 0
			)
		end
		
		it "handles empty collections" do
			empty_array = []
			usage = subject.of(empty_array)
			expect(usage).to have_attributes(
				count: be == 1,
				size: be > 0
			)
		end
		
		it "counts strings and their memory" do
			string = "Hello, World!" * 100
			usage = subject.of(string)
			expect(usage).to have_attributes(
				count: be == 1,
				size: be > 100  # Should be larger than the string content
			)
		end
		
		it "can compute usage of proc" do
			proc = Proc.new{|x| x * 2}
			usage = subject.of(proc)
			expect(usage).to have_attributes(
				count: be > 1,
				size: be > 0
			)
		end
	end
end
