# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "set"

module Memory
	# Tracks object traversal paths for memory analysis.
	#
	# The Graph class maintains a mapping of objects to their parent objects,
	# allowing you to trace the reference path from any object back to its root.
	class Graph
		def initialize
			@mapping = Hash.new.compare_by_identity
		end
		
		# The internal mapping of objects to their parents.
		attr_reader :mapping
		
		# Add a parent-child relationship to the via mapping.
		#
		# @parameter child [Object] The child object.
		# @parameter parent [Object] The parent object that references the child.
		def []=(child, parent)
			@mapping[child] = parent
		end
		
		# Get the parent of an object.
		#
		# @parameter child [Object] The child object.
		# @returns [Object | Nil] The parent object, or nil if not tracked.
		def [](child)
			@mapping[child]
		end
		
		# Check if an object is tracked in the via mapping.
		#
		# @parameter object [Object] The object to check.
		# @returns [Boolean] True if the object is tracked.
		def key?(object)
			@mapping.key?(object)
		end
		
		# Find how a parent object references a child object.
		#
		# @parameter parent [Object] The parent object.
		# @parameter child [Object] The child object to find.
		# @returns [String | Nil] A human-readable description of the reference, or nil if not found.
		def find_reference(parent, child)
			# Check instance variables:
			parent.instance_variables.each do |ivar|
				value = parent.instance_variable_get(ivar)
				if value.equal?(child)
					return ivar.to_s
				end
			end
			
			# Check array elements:
			if parent.is_a?(Array)
				parent.each_with_index do |element, index|
					if element.equal?(child)
						return "[#{index}]"
					end
				end
			end
			
			# Check hash keys and values:
			if parent.is_a?(Hash)
				parent.each do |key, value|
					if value.equal?(child)
						return "[#{key.inspect}]"
					end
					if key.equal?(child)
						return "(key: #{key.inspect})"
					end
				end
			end
			
			# Check struct members:
			if parent.is_a?(Struct)
				parent.each_pair do |member, value|
					if value.equal?(child)
						return ".#{member}"
					end
				end
			end
			
			# Could not determine the reference:
			return nil
		end
		
		# Construct a human-readable path from an object back to a root.
		#
		# @parameter object [Object] The object to trace back from.
		# @parameter root [Object | Nil] The root object to trace to. If nil, traces to any root.
		# @returns [Array(Array(Object), Array(String))] A tuple of [object_path, reference_path].
		def path_to(object, root = nil)
			# Build the object path by following via backwards:
			object_path = [object]
			current = object
			
			while @mapping.key?(current)
				parent = @mapping[current]
				object_path << parent
				current = parent
				
				# Stop if we reached the specified root:
				break if root && current.equal?(root)
			end
			
			# Reverse to get path from root to object:
			object_path.reverse!
			
			return object_path
		end
		
		# Format a human-readable path string.
		#
		# @parameter object [Object] The object to trace back from.
		# @parameter root [Object | Nil] The root object to trace to. If nil, traces to any root.
		# @returns [String] A formatted path string.
		def path(object, root = nil)
			object_path = path_to(object, root)
			
			# Start with the root object description:
			parts = ["#<#{object_path.first.class}:0x%016x>" % (object_path.first.object_id << 1)]
			
			# Append each reference in the path:
			(1...object_path.size).each do |i|
				parent = object_path[i - 1]
				child = object_path[i]
				
				parts << (find_reference(parent, child) || "<??>")
			end
			
			return parts.join
		end
	end
end

