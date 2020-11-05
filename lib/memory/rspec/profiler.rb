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

require_relative '../sampler'

module Memory
	module RSpec
		module Profiler
			def self.profile(scope)
				memory_sampler = nil
				
				scope.before(:all) do |example_group|
					name = example_group.class.description.gsub(/[^\w]+/, "-")
					path = "#{name}.mprof"
					
					skip if File.exist?(path)
					
					memory_sampler = Memory::Sampler.new
					memory_sampler.start
				end
				
				scope.after(:all) do |example_group|
					name = example_group.class.description.gsub(/[^\w]+/, "-")
					path = "#{name}.mprof"
					
					if memory_sampler
						memory_sampler.stop
						
						File.open(path, "w", encoding: Encoding::BINARY) do |io|
							memory_sampler.dump(io)
						end
						
						memory_sampler = nil
					end
				end
				
				scope.after(:suite) do
					memory_sampler = Memory::Sampler.new
					
					Dir.glob("*.mprof") do |path|
						memory_sampler.load(File.read(
							path,
							encoding: Encoding::BINARY,
						))
					end
					
					memory_sampler.report.print
				end
			end
		end
	end
end
