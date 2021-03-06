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

module Memory
	class Cache
		def initialize
			@gem_guess_cache = Hash.new
			@location_cache = Hash.new { |h, k| h[k] = Hash.new.compare_by_identity }
			@class_name_cache = Hash.new.compare_by_identity
			@string_cache = Hash.new
		end

		def guess_gem(path)
			@gem_guess_cache[path] ||=
				if /(\/gems\/.*)*\/gems\/(?<gemname>[^\/]+)/ =~ path
					gemname
				elsif /\/rubygems[\.\/]/ =~ path
					"rubygems"
				elsif /ruby\/2\.[^\/]+\/(?<stdlib>[^\/\.]+)/ =~ path
					stdlib
				elsif /(?<app>[^\/]+\/(bin|app|lib))/ =~ path
					app
				else
					"other"
				end
		end

		def lookup_location(file, line)
			@location_cache[file][line] ||= "#{file}:#{line}"
		end

		def lookup_class_name(klass)
			@class_name_cache[klass] ||= ((klass.is_a?(Class) && klass.name) || '<<Unknown>>').to_s
		end

		def lookup_string(obj)
			# This string is shortened to 200 characters which is what the string report shows
			# The string report can still list unique strings longer than 200 characters
			#   separately because the object_id of the shortened string will be different
			@string_cache[obj] ||= String.new << obj[0, 64]
		end
	end
end
