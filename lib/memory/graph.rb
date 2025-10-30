# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "usage"
require "json"

module Memory
	# Tracks object traversal paths for memory analysis.
	module Graph
		IGNORE = Usage::IGNORE
		
		# Represents a node in the object graph with usage information.
		class Node
			def initialize(object, usage = Usage.new, parent = nil, reference: nil)
				@object = object
				@usage = usage
				@parent = parent
				@children = nil
				
				@reference = reference || parent&.find_reference(object)
				@total_usage = nil
				@path = nil
			end
			
			# @attribute [Object] The object this node represents.
			attr_accessor :object
			
			# @attribute [Usage] The memory usage of this object (not including children).
			attr_accessor :usage
			
			# @attribute [Node | Nil] The parent node (nil for root).
			attr_accessor :parent
			
			# @attribute [Hash(String, Node) | Nil] Child nodes reachable from this object (hash of reference => node).
			attr_accessor :children
			
			# @attribute [String | Nil] The reference to the parent object (nil for root).
			attr_accessor :reference
			
			# Add a child node to this node.
			#
			# @parameter child [Node] The child node to add.
			# @returns [self] Returns self for chaining.
			def add(child)
				@children ||= {}
				
				# Use the reference as the key, or a fallback if not found:
				key = child.reference || "(#{@children.size})"
				
				@children[key] = child
				
				return self
			end
			
			# Compute total usage including all children.
			def total_usage
				unless @total_usage 
					@total_usage = Usage.new(@usage.size, @usage.count)
					
					@children&.each_value do |child|
						child_total = child.total_usage
						@total_usage.add!(child_total)
					end
				end
				
				return @total_usage
			end
			
			# Find how this node references a child object.
			#
			# @parameter child [Object] The child object to find.
			# @returns [String | Nil] A human-readable description of the reference, or nil if not found.
			def find_reference(child)
				# Check instance variables:
				@object.instance_variables.each do |ivar|
					value = @object.instance_variable_get(ivar)
					if value.equal?(child)
						return ivar.to_s
					end
				end
				
				# Check array elements:
				if @object.is_a?(Array)
					@object.each_with_index do |element, index|
						if element.equal?(child)
							return "[#{index}]"
						end
					end
				end
				
				# Check hash keys and values:
				if @object.is_a?(Hash)
					@object.each do |key, value|
						if value.equal?(child)
							return "[#{key.inspect}]"
						end
						if key.equal?(child)
							return "(key: #{key.inspect})"
						end
					end
				end
				
				# Check struct members:
				if @object.is_a?(Struct)
					@object.each_pair do |member, value|
						if value.equal?(child)
							return ".#{member}"
						end
					end
				end
				
				# Could not determine the reference:
				return nil
			end
			
			# Get the path string from root to this node (cached).
			#
			# @returns [String | Nil] The formatted path string, or nil if no graph available.
			def path
				unless @path
					# Build object path from root to this node:
					object_path = []
					current = self
					
					while current
						object_path.unshift(current)
						current = current.parent
					end
					
					# Format the path:
					parts = ["#<#{object_path.first.object.class}:0x%016x>" % (object_path.first.object.object_id << 1)]
					
					# Append each reference in the path:
					(1...object_path.size).each do |i|
						parent_node = object_path[i - 1]
						child_node = object_path[i]
						
						parts << (parent_node.find_reference(child_node.object) || "<??>")
					end
					
					@path = parts.join
				end
				
				return @path
			end
			
			# Convert this node to a JSON-compatible hash.
			#
			# @parameter options [Hash] Options for JSON serialization.
			# @returns [Hash] A hash representation of this node.
			def as_json(*)
				json = {
					path: path,
						object: {
							class: @object.class.name,
							object_id: @object.object_id
						},
						usage: @usage.as_json,
				}

				if @children&.any?
					json[:total_usage] = total_usage.as_json
					json[:children] = @children.transform_values(&:as_json)
				end

				return json
			end
			
			# Convert this node to a JSON string.
			#
			# @parameter options [Hash] Options for JSON serialization.
			# @returns [String] A JSON string representation of this node.
			def to_json(...)
				as_json.to_json(...)
			end
		end
		
		# Build a graph of nodes from a root object, computing usage at each level.
		#
		# @parameter root [Object] The root object to start from.
		# @parameter depth [Integer] Maximum depth to traverse (nil for unlimited).
		# @parameter seen [Set] Set of already seen objects (for internal use).
		# @parameter ignore [Array] Array of types to ignore during traversal.
		# @parameter parent [Node | Nil] The parent node (for internal use).
		# @returns [Node] The root node with children populated.
		def self.for(root, depth: nil, seen: Set.new.compare_by_identity, ignore: IGNORE, parent: nil)
			if depth && depth <= 0
				# Compute shallow usage for this object and it's children:
				usage = Usage.of(root, seen: seen, ignore: ignore)
				return Node.new(root, usage, parent)
			end
			
			# Compute shallow usage for just this object:
			usage = Usage.new(ObjectSpace.memsize_of(root), 1)
			
			# Create the node:
			node = Node.new(root, usage, parent)
			
			# Mark this object as seen:
			seen.add(root)
			
			# Traverse children:
			ObjectSpace.reachable_objects_from(root)&.each do |reachable_object|
				# Skip ignored types:
				next if ignore.any?{|type| reachable_object.is_a?(type)}
				
				# Skip internal objects:
				next if reachable_object.is_a?(ObjectSpace::InternalObjectWrapper)
				
				# Skip already seen objects:
				next if seen.include?(reachable_object)
				
				# Recursively build child node:
				node.add(self.for(reachable_object, depth: depth ? depth - 1 : nil, seen: seen, ignore: ignore, parent: node))
			end
			
			return node
		end
	end
end
