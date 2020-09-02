# frozen_string_literal: true

# Copyright, 2020, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

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
