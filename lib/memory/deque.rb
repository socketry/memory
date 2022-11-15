# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Samuel Williams.

require 'objspace'
require 'msgpack'

module Memory
	class Deque
		def initialize
			@segments = []
			@last = nil
		end
		
		def freeze
			return self if frozen?
			
			@segments.each(&:freeze)
			@last = nil
			
			super
		end
		
		include Enumerable
		
		def concat(segment)
			@segments << segment
			@last = nil
			
			return self
		end
		
		def << item
			unless @last
				@last = []
				@segments << @last
			end
			
			@last << item
			
			return self
		end
		
		def each(&block)
			@segments.each do |segment|
				segment.each(&block)
			end
		end
		
		def size
			@segments.sum(&:size)
		end
	end
end
