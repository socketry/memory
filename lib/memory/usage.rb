# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "format"

require "set"
require "objspace"

module Memory
	class Usage
		def initialize(size = 0, count = 0)
			@size = size
			@count = count
		end
		
		# @attribute size [Integer] The total size of the usage in bytes.
		attr_accessor :size
		
		alias memsize size
		
		# @attribute count [Integer] The total count of the usage in object instances.
		attr_accessor :count
		
		# Add an allocation to this usage.
		# @parameter allocation [Allocation] The allocation to add.
		def << allocation
			self.size += allocation.memsize
			self.count += 1
			
			return self
		end
		
		# Compute the usage of an object and all reachable objects from it.
		# @parameter root [Object] The root object to start traversal from.
		# @returns [Usage] The usage of the object and all reachable objects from it.
		def self.of(root)
			seen = Set.new.compare_by_identity
			
			count = 0
			size = 0
			
			queue = [root]
			while queue.any?
				object = queue.shift
				# Skip modules and symbols, they are usually "global":
				next if object.is_a?(Module)
				# Note that `reachable_objects_from` does not include symbols, numbers, or other value types, AFAICT.
				
				# Skip objects we have already seen:
				next if seen.include?(object)
				
				# Add the object to the seen set and update the count and size:
				seen.add(object)
				count += 1
				size += ObjectSpace.memsize_of(object)
				
				# Add the object's reachable objects to the queue:
				queue.concat(ObjectSpace.reachable_objects_from(object))
			end
			
			return new(size, count)
		end
		
		def as_json(...)
			{
				size: @size,
				count: @count
			}
		end
		
		def to_json(...)
			as_json.to_json(...)
		end
		
		def to_s
			"(#{Memory.formatted_bytes(memory)} in #{count} allocations)"
		end
	end
end
