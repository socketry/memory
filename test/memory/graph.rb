# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "memory/graph"
require "memory/usage"

describe Memory::Graph do
	with "Memory::Graph::Node" do
	with "#initialize" do
		it "creates a node for an object" do
			obj = Object.new
			node = Memory::Graph::Node.new(obj)
			
			expect(node.object).to be == obj
			expect(node.children).to be_nil
		end
		
	it "can set reference from parent" do
		parent = [Object.new]
		child_obj = parent[0]
		parent_node = Memory::Graph::Node.new(parent)
		child_node = Memory::Graph::Node.new(child_obj, Memory::Usage.new, parent_node)
		
		expect(child_node.reference).to be == "[0]"
	end
	end
		
	with "#total_usage" do
		it "returns usage for node without children" do
			node = Memory::Graph::Node.new(Object.new, Memory::Usage.new(100, 1))
			
			total = node.total_usage
			expect(total.size).to be == 100
			expect(total.count).to be == 1
		end
		
		it "sums usage from children" do
			root_node = Memory::Graph::Node.new(Object.new, Memory::Usage.new(100, 1))
			
			child1 = Memory::Graph::Node.new(Object.new, Memory::Usage.new(50, 1), root_node, reference: "child1")
			child2 = Memory::Graph::Node.new(Object.new, Memory::Usage.new(75, 1), root_node, reference: "child2")
			
			root_node.add(child1)
			root_node.add(child2)
			
			total = root_node.total_usage
			expect(total.size).to be == 225  # 100 + 50 + 75
			expect(total.count).to be == 3   # 1 + 1 + 1
		end
		
		it "recursively sums nested children" do
			root = Memory::Graph::Node.new(Object.new, Memory::Usage.new(100, 1))
			child = Memory::Graph::Node.new(Object.new, Memory::Usage.new(50, 1), root, reference: "child")
			grandchild = Memory::Graph::Node.new(Object.new, Memory::Usage.new(25, 1), child, reference: "grandchild")
			
			child.add(grandchild)
			root.add(child)
			
			total = root.total_usage
			expect(total.size).to be == 175  # 100 + 50 + 25
			expect(total.count).to be == 3   # 1 + 1 + 1
		end
	end
		
		with "#path" do
			it "returns cached path string" do
				root = [Object.new]
				node = Memory::Graph.for(root)
				
				# First call computes and caches:
				path1 = node.path
				expect(path1).to be_a(String)
				expect(path1).to be =~ /^#<Array:/
				
				# Second call returns cached value:
				path2 = node.path
				expect(path2).to be == path1
				expect(path2.object_id).to be == path1.object_id  # Same string object
			end
			
			it "works for child nodes" do
				root = [Object.new]
				node = Memory::Graph.for(root)
				
				child = node.children["[0]"]
				path = child.path
				
				expect(path).to be_a(String)
				expect(path).to be =~ /\[0\]$/
			end
			
			it "works even without graph instance" do
				obj = Object.new
				node = Memory::Graph::Node.new(obj)
				
				# Should still be able to format path (just shows the object)
				path = node.path
				expect(path).to be_a(String)
				expect(path).to be =~ /^#<Object:/
			end
		end
		
	with "#as_json" do
		it "produces minimal representation for leaf nodes" do
			obj = Object.new
			node = Memory::Graph.for(obj, depth: 0)
			json_data = node.as_json
			
			# Leaf nodes only have path, object, and usage
			expect(json_data).to have_keys(
				path: be_a(String),
				object: be_a(Hash),
				usage: be_a(Hash)
			)
			
			# Should NOT have total_usage or children
			expect(json_data).not.to be(:key?, :total_usage)
			expect(json_data).not.to be(:key?, :children)
			
			expect(json_data[:object]).to have_keys(
				class: be == "Object",
				object_id: be == obj.object_id
			)
		end
		
		it "includes total_usage and children for internal nodes" do
			root = [Object.new]
			node = Memory::Graph.for(root)
			json_data = node.as_json
			
			# Internal nodes have all fields
			expect(json_data).to have_keys(
				path: be_a(String),
				object: be_a(Hash),
				usage: be_a(Hash),
				total_usage: be_a(Hash),
				children: be_a(Hash)
			)
			
			expect(json_data[:usage]).to have_keys(
				size: be > 0,
				count: be == 1
			)
			
			expect(json_data[:total_usage]).to have_keys(
				size: be > 0,
				count: be == 2  # root + child
			)
		end
		
		it "recursively serializes children as hash" do
			root = [Object.new, Object.new]
			node = Memory::Graph.for(root)
			json_data = node.as_json
			
			expect(json_data[:children].size).to be == 2
			expect(json_data[:children]).to have_keys(
				"[0]" => be_a(Hash),
				"[1]" => be_a(Hash)
			)
			
			# Child nodes are leaves, so minimal representation
			child = json_data[:children]["[0]"]
			expect(child).to have_keys(
				path: be_a(String),
				object: be_a(Hash),
				usage: be_a(Hash)
			)
			
			# Children should NOT have total_usage or children fields
			expect(child).not.to be(:key?, :total_usage)
			expect(child).not.to be(:key?, :children)
		end
	end
		
	with "#to_json" do
		it "produces minimal JSON for leaf nodes" do
			obj = Object.new
			node = Memory::Graph.for(obj, depth: 0)
			json_string = node.to_json
			
			expect(json_string).to be_a(String)
			
			parsed = JSON.parse(json_string)
			expect(parsed).to have_keys(
				"path" => be_a(String),
				"object" => be_a(Hash),
				"usage" => be_a(Hash)
			)
			
			# Should NOT have total_usage or children
			expect(parsed).not.to be(:key?, "total_usage")
			expect(parsed).not.to be(:key?, "children")
		end
		
		it "round-trips through JSON with full structure" do
			root = [Object.new]
			node = Memory::Graph.for(root)
			
			json_string = node.to_json
			parsed = JSON.parse(json_string)
			
			# Root has children, so has all fields
			expect(parsed["usage"]["count"]).to be == 1
			expect(parsed["total_usage"]["count"]).to be == 2
			expect(parsed["children"].size).to be == 1
			expect(parsed["children"]["[0]"]).to be_a(Hash)
			
			# Child is a leaf, so no total_usage/children
			child = parsed["children"]["[0]"]
			expect(child).not.to be(:key?, "total_usage")
			expect(child).not.to be(:key?, "children")
		end
	end
	end
	
	with ".for" do
		it "creates a node for a simple object" do
			obj = Object.new
			node = Memory::Graph.for(obj)
			
			expect(node.object).to be == obj
			expect(node.usage).to be_a(Memory::Usage)
			expect(node.usage.count).to be == 1
		end
		
		it "creates child nodes for reachable objects" do
			root = [Object.new, Object.new]
			node = Memory::Graph.for(root)
			
			expect(node.object).to be == root
			expect(node.children.size).to be == 2
			expect(node.children["[0]"].object).to be == root[0]
			expect(node.children["[1]"].object).to be == root[1]
		end
		
	it "respects depth parameter" do
		# Create nested structure: root -> array -> inner array -> object
		obj = Object.new
		inner = [obj]
		outer = [inner]
		root = [outer]
		
		# Depth 0: only root
		node = Memory::Graph.for(root, depth: 0)
		expect(node.children).to be_nil
		
		# Depth 1: root + outer
		node = Memory::Graph.for(root, depth: 1)
		expect(node.children.size).to be == 1
		expect(node.children["[0]"].children).to be_nil
		
		# Depth 2: root + outer + inner
		node = Memory::Graph.for(root, depth: 2)
		expect(node.children.size).to be == 1
		expect(node.children["[0]"].children.size).to be == 1
		expect(node.children["[0]"].children["[0]"].children).to be_nil
	end
		
		it "computes usage at each node" do
			root = [Object.new]
			node = Memory::Graph.for(root)
			
			# Root should have usage
			expect(node.usage).to be_a(Memory::Usage)
			expect(node.usage.size).to be > 0
			
			# Child should have usage
			expect(node.children["[0]"].usage).to be_a(Memory::Usage)
			expect(node.children["[0]"].usage.size).to be > 0
		end
		
	it "prevents circular reference loops" do
		array = []
		array << array  # Circular reference
		
		node = Memory::Graph.for(array)
		
		# Should not infinite loop, should have one node with no children
		expect(node.object).to be == array
		expect(node.children).to be_nil
	end
		
		it "handles shared objects" do
			shared = Object.new
			array = [shared, shared]
			
			node = Memory::Graph.for(array)
			
			# Should only create one node for shared object (first reference wins)
			expect(node.children.size).to be == 1
			expect(node.children["[0]"].object).to be == shared
		end
		
		it "computes correct total_usage" do
			root = [Object.new, Object.new]
			node = Memory::Graph.for(root)
			
			total = node.total_usage
			
			# Total should include root + 2 children
			expect(total.count).to be == 3
			expect(total.size).to be > node.usage.size
		end
		
	it "accumulates total usage at leaf nodes when depth is limited" do
		# Create nested structure with known objects at each level
		obj3 = Object.new
		obj2 = Object.new
		level2 = [obj2, obj3]  # 1 array + 2 objects = 3 objects
		obj1 = Object.new
		level1 = [obj1, level2]  # 1 array + 1 object + level2 subtree
		root = [level1]
		
		# Build with depth=1: root can see level1, but level1's children become leaf nodes
		node = Memory::Graph.for(root, depth: 1)
		
		# Root should have one child (level1)
		expect(node.children.size).to be == 1
		level1_node = node.children["[0]"]
		
		# level1 should have no children (depth limit reached)
		expect(level1_node.children).to be_nil
		
		# But level1's usage should include ALL its descendants
		# level1 array + obj1 + level2 array + obj2 + obj3 = 5 objects total
		expect(level1_node.usage.count).to be == 5
		
		# Compare with unlimited depth to verify
		unlimited = Memory::Graph.for(root)
		level1_unlimited = unlimited.children["[0]"]
		
		# With unlimited depth, level1's total_usage should equal depth-limited usage
		expect(level1_node.usage.count).to be == level1_unlimited.total_usage.count
	end
	
	it "leaf nodes at depth limit contain their full subtree usage" do
		# Nested: root -> child -> grandchild -> great-grandchild
		great = Object.new
		grand = [great]
		child = [grand]
		root = [child]
		
		# Depth 1: root can see child, but child becomes a leaf with accumulated usage
		node = Memory::Graph.for(root, depth: 1)
		
		child_node = node.children["[0]"]
		
		# Child has no children (depth limit)
		expect(child_node.children).to be_nil
		
		# But child's usage includes: child array + grand array + great object = 3 objects
		expect(child_node.usage.count).to be == 3
		
		# Total for root should be root + child's accumulated subtree
		expect(node.total_usage.count).to be == 4  # root + 3 from child subtree
	end
	end
end

