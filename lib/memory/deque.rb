# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require "objspace"
require "msgpack"

module Memory
	# A double-ended queue implementation optimized for memory profiling.
	# Stores items in segments to reduce memory reallocation overhead.
	class Deque
		# Initialize a new empty deque.
		def initialize
			@segments = []
			@last = nil
		end
		
		# Freeze this deque and all its segments.
		# @returns [Deque] Self.
		def freeze
			return self if frozen?
			
			@segments.each(&:freeze)
			@last = nil
			
			super
		end
		
		include Enumerable
		
		# Concatenate an array segment to this deque.
		# @parameter segment [Array] The segment to append.
		# @returns [Deque] Self.
		def concat(segment)
			@segments << segment
			@last = nil
			
			return self
		end
		
		# Append an item to this deque.
		# @parameter item [Object] The item to append.
		# @returns [Deque] Self.
		def << item
			unless @last
				@last = []
				@segments << @last
			end
			
			@last << item
			
			return self
		end
		
		# Iterate over all items in the deque.
		# @parameter block [Block] The block to yield each item to.
		def each(&block)
			@segments.each do |segment|
				segment.each(&block)
			end
		end
		
		# Get the total number of items in the deque.
		# @returns [Integer] The total number of items across all segments.
		def size
			@segments.sum(&:size)
		end
	end
end
