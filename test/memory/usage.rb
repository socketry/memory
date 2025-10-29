# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2025, by Samuel Williams.

require "memory/usage"
require "json"

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
		# Proc is in default IGNORE list, so we need a custom ignore that allows Proc
		# but still includes Module to prevent deep traversal
		usage = subject.of(proc, ignore: [Module])
		expect(usage).to have_attributes(
			count: be > 1,
			size: be > 0
		)
	end
	
	it "can compute usage of nil" do
			usage = subject.of(nil)
			expect(usage).to have_attributes(
				count: be == 0,
				size: be == 0
			)
		end
		
		it "can compute usage of numbers" do
			usage = subject.of(42)
			expect(usage).to have_attributes(
				count: be == 1,
				size: be == 0
			)
		end
		
		with "seen parameter" do
			it "allows sharing seen set across multiple calls" do
				# Create a shared seen set
				seen = Set.new.compare_by_identity
				
				shared_object = Object.new
				array1 = [shared_object]
				array2 = [shared_object]
				
				# First call tracks the array and shared object
				usage1 = subject.of(array1, seen: seen)
				expect(usage1.count).to be == 2  # array1 + shared_object
				
				# Second call should skip shared_object since it's already in seen
				usage2 = subject.of(array2, seen: seen)
				expect(usage2.count).to be == 1  # Only array2, shared_object already seen
			end
			
			it "respects pre-populated seen set" do
				seen = Set.new.compare_by_identity
				
				existing_object = Object.new
				seen.add(existing_object)
				
				array = [existing_object, Object.new]
				usage = subject.of(array, seen: seen)
				
				# Should count array + new object, but not existing_object
				expect(usage.count).to be == 2
			end
			
			it "updates seen set during traversal" do
				seen = Set.new.compare_by_identity
				
				object = [Object.new, Object.new]
				usage = subject.of(object, seen: seen)
				
				# All 3 objects should now be in seen
				expect(seen.size).to be == 3
			end
			
			it "prevents counting same object graph twice" do
				seen = Set.new.compare_by_identity
				
				root = {data: [1, 2, 3]}
				
				# First traversal
				usage1 = subject.of(root, seen: seen)
				first_count = usage1.count
				
				# Second traversal with same seen set should find nothing new
				usage2 = subject.of(root, seen: seen)
				expect(usage2.count).to be == 0
			end
		end
		
		with "ignore parameter" do
			it "skips specified types from traversal" do
				# Create a custom ignore list that includes String
				custom_ignore = [Module, String]
				
				array = [Object.new, "ignored string", Object.new]
				usage = subject.of(array, ignore: custom_ignore)
				
				# Should count array + 2 objects, but not the string
				expect(usage.count).to be == 3
			end
			
			it "uses default IGNORE constant when not specified" do
				# Test that Module is ignored by default
				object = [Object.new, String]
				usage = subject.of(object)
				
				expect(usage.count).to be == 2 # array + object, not String (Module).
			end
			
			it "can provide different ignore list" do
				# Provide an ignore list that doesn't include String
				# (but still includes Module to avoid deep traversal)
				custom_ignore = [Module]
				
				string = "test string"
				object = [string]
				
				usage_with_default = subject.of(object)
				usage_with_custom = subject.of(object, ignore: custom_ignore)
				
				# Both should count the array and string (String class is a Module, but string instances aren't)
				expect(usage_with_default.count).to be == 2
				expect(usage_with_custom.count).to be == 2
			end
			
			it "ignores Proc by default" do
				proc = Proc.new { "test" }
				array = [proc]
				usage = subject.of(array)
				
				# Should count only the array, not the Proc
				expect(usage.count).to be == 1
			end
			
			it "ignores Thread by default" do
				thread = Thread.current
				array = [thread]
				usage = subject.of(array)
				
				# Should count only the array, not the Thread
				expect(usage.count).to be == 1
			end
			
			it "ignores Fiber by default" do
				fiber = Fiber.new { "test" }
				array = [fiber]
				usage = subject.of(array)
				
				# Should count only the array, not the Fiber
				expect(usage.count).to be == 1
			end
			
			it "ignores Method by default" do
				method = Object.new.method(:to_s)
				array = [method]
				usage = subject.of(array)
				
				# Should count only the array, not the Method
				expect(usage.count).to be == 1
			end
			
			it "can override ignore list to include custom types" do
				# Define a custom class
				custom_class = Class.new
				instance = custom_class.new
				
				# Create ignore list that includes our custom class
				custom_ignore = [Module, custom_class]
				
				array = [instance, Object.new]
				usage = subject.of(array, ignore: custom_ignore)
				
				# Should count array + Object, but not custom_class instance
				expect(usage.count).to be == 2
			end
			
			it "checks ignore list with is_a? for inheritance" do
				# Create a subclass
				parent_class = Class.new
				child_class = Class.new(parent_class)
				
				parent_instance = parent_class.new
				child_instance = child_class.new
				
				# Ignore parent class
				custom_ignore = [Module, parent_class]
				
				array = [parent_instance, child_instance]
				usage = subject.of(array, ignore: custom_ignore)
				
				# Both instances should be ignored (child is_a? parent)
				expect(usage.count).to be == 1  # Only the array
			end
		end
		
		with "combined seen and ignore parameters" do
			it "applies both seen and ignore filters" do
				seen = Set.new.compare_by_identity
				existing = Object.new
				seen.add(existing)
				
				custom_ignore = [Module, String]
				
				array = [existing, "ignored", Object.new]
				usage = subject.of(array, seen: seen, ignore: custom_ignore)
				
				# Should count array + new object only
				# (existing is in seen, string is in ignore)
				expect(usage.count).to be == 2
			end
			
			it "checks ignore before adding to seen" do
				seen = Set.new.compare_by_identity
				custom_ignore = [Module, String]
				
				array = ["ignored string"]
				usage = subject.of(array, seen: seen, ignore: custom_ignore)
				
				# String should not be added to seen since it's ignored
				expect(seen.size).to be == 1  # Only array
				expect(seen).not.to be(:include?, "ignored string")
			end
			
			it "preserves seen across multiple calls with different ignore lists" do
				seen = Set.new.compare_by_identity
				
				# First call with default ignore
				obj1 = [Object.new]
				usage1 = subject.of(obj1, seen: seen)
				count1 = seen.size
				
				# Second call with custom ignore
				obj2 = [Object.new, "test"]
				usage2 = subject.of(obj2, seen: seen, ignore: [Module])
				
				# Seen should have accumulated objects from both calls
				expect(seen.size).to be > count1
			end
		end
	end
	
	with "#to_s" do
		it "produces a human-readable string" do
			usage = subject.new(2048, 5)
			expect(usage.to_s).to be == "(2.00 KiB in 5 allocations)"
		end
	end
	
	with "#as_json" do
		it "produces a hash representation" do
			usage = subject.new(4096, 10)
			json_data = usage.as_json
			
			expect(json_data).to have_keys(
				size: be == 4096,
				count: be == 10
			)
		end
	end
	
	with "#to_json" do
		it "produces a JSON string" do
			usage = subject.new(8192, 20)
			json_string = usage.to_json
			
			expect(json_string).to be_a(String)
			expect(JSON.parse(json_string)).to have_keys(
				"size" => be == 8192,
				"count" => be == 20
			)
		end
	end
end
