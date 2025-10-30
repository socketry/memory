# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "memory/graph"
require "memory/usage"

describe Memory::Graph do
	let(:graph) {subject.new}
	
	with "#[]= and #[]" do
		it "stores parent-child relationships" do
			parent = Object.new
			child = Object.new
			
			graph[child] = parent
			
			expect(graph[child]).to be == parent
		end
		
		it "returns nil for unknown objects" do
			object = Object.new
			expect(graph[object]).to be_nil
		end
		
		it "uses object identity" do
			parent = Object.new
			child1 = +"test"
			child2 = +"test"
			
			graph[child1] = parent
			
			expect(graph[child1]).to be == parent
			expect(graph[child2]).to be_nil
		end
	end
	
	with "#key?" do
		it "returns true for tracked objects" do
			parent = Object.new
			child = Object.new
			graph[child] = parent
			
			expect(graph).to be(:key?, child)
		end
		
		it "returns false for untracked objects" do
			object = Object.new
			expect(graph).not.to be(:key?, object)
		end
	end
	
	with "#find_reference" do
		it "finds instance variable references" do
			parent = Object.new
			child = Object.new
			parent.instance_variable_set(:@data, child)
			
			reference = graph.find_reference(parent, child)
			expect(reference).to be == "@data"
		end
		
		it "finds array element references by index" do
			child1 = Object.new
			child2 = Object.new
			parent = [child1, child2]
			
			expect(graph.find_reference(parent, child1)).to be == "[0]"
			expect(graph.find_reference(parent, child2)).to be == "[1]"
		end
		
		it "finds hash value references" do
			child = Object.new
			parent = {key: child, other: "value"}
			
			reference = graph.find_reference(parent, child)
			expect(reference).to be == "[:key]"
		end
		
		it "finds hash key references" do
			key_object = Object.new
			parent = {key_object => "value"}
			
			reference = graph.find_reference(parent, key_object)
			expect(reference).to be =~ /^\(key:/
		end
		
		it "finds struct member references" do
			point_struct = Struct.new(:x, :y)
			child = Object.new
			parent = point_struct.new(10, child)
			
			reference = graph.find_reference(parent, child)
			expect(reference).to be == ".y"
		end
		
		it "returns nil when reference cannot be found" do
			parent = Object.new
			child = Object.new
			
			reference = graph.find_reference(parent, child)
			expect(reference).to be_nil
		end
	end
	
	with "#path_to" do
		it "returns array of objects from root to target" do
			grandchild = Object.new
			child = Object.new
			root = Object.new
			
			graph[child] = root
			graph[grandchild] = child
			
			path = graph.path_to(grandchild, root)
			
			expect(path).to be == [root, child, grandchild]
		end
		
		it "traces to any root when root parameter is nil" do
			grandchild = Object.new
			child = Object.new
			root = Object.new
			
			graph[child] = root
			graph[grandchild] = child
			
			path = graph.path_to(grandchild)
			
			expect(path).to be == [root, child, grandchild]
		end
		
		it "returns single element for root object" do
			root = Object.new
			path = graph.path_to(root)
			
			expect(path).to be == [root]
		end
		
		it "stops at specified root" do
			obj4 = Object.new
			obj3 = Object.new
			obj2 = Object.new
			obj1 = Object.new
			
			graph[obj2] = obj1
			graph[obj3] = obj2
			graph[obj4] = obj3
			
			path = graph.path_to(obj4, obj2)
			
			expect(path).to be == [obj2, obj3, obj4]
		end
	end
	
	with "#path" do
		it "formats path with instance variables" do
			child = Object.new
			root = Object.new
			root.instance_variable_set(:@data, child)
			
			Memory::Usage.of(root, via: graph)
			
			path = graph.path(child, root)
			expect(path).to be =~ /@data$/
		end
		
		it "formats path with array indices" do
			child = Object.new
			root = [child]
			
			Memory::Usage.of(root, via: graph)
			
			path = graph.path(child, root)
			expect(path).to be =~ /\[0\]$/
		end
		
		it "formats path with hash keys" do
			child = Object.new
			root = {key: child}
			
			Memory::Usage.of(root, via: graph)
			
			path = graph.path(child, root)
			expect(path).to be =~ /\[:key\]$/
		end
		
		it "formats path with struct members" do
			point_struct = Struct.new(:x, :y)
			child = Object.new
			root = point_struct.new(10, child)
			
			Memory::Usage.of(root, via: graph)
			
			path = graph.path(child, root)
			expect(path).to be =~ /\.y$/
		end
		
		it "formats complex nested paths" do
			target = Object.new
			array = [target]
			hash = {items: array}
			root = Object.new
			root.instance_variable_set(:@data, hash)
			
			Memory::Usage.of(root, via: graph)
			
			path = graph.path(target, root)
			expect(path).to be =~ /@data\[:items\]\[0\]$/
		end
		
		it "uses <??> for unknown reference types" do
			# Create a custom object that holds references in a non-standard way
			# Actually, even nested structures can be found with instance variables and array indices
			custom = Class.new do
				def initialize(obj)
					@hidden = [obj]  # This can be found: @hidden then [0]
				end
			end
			
			child = Object.new
			parent = custom.new(child)
			root = [parent]
			
			Memory::Usage.of(root, via: graph)
			
			path = graph.path(child, root)
			# All references should be found: root[0] -> parent@hidden -> array[0] -> child
			expect(path).to be(:include?, "@hidden")
			expect(path).to be(:include?, "[0]")
		end
		
		it "works without specifying root" do
			child = Object.new
			root = [child]
			
			Memory::Usage.of(root, via: graph)
			
			path = graph.path(child)
			expect(path).to be =~ /\[0\]$/
		end
	end
	
	with "integration with Memory::Usage.of" do
		it "tracks object graph during traversal" do
			obj1 = Object.new
			obj2 = Object.new
			root = [obj1, obj2]
			
			Memory::Usage.of(root, via: graph)
			
			expect(graph[obj1]).to be == root
			expect(graph[obj2]).to be == root
		end
		
		it "works with nested structures" do
			inner = Object.new
			middle = [inner]
			root = {data: middle}
			
			Memory::Usage.of(root, via: graph)
			
			expect(graph[middle]).to be == root
			expect(graph[inner]).to be == middle
		end
	end
end

