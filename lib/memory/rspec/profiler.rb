# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require_relative "../sampler"

module Memory
	# @namespace
	module RSpec
		# Integration with RSpec for memory profiling test suites.
		# Profiles memory allocations for RSpec example groups and generates reports.
		module Profiler
			# Profile memory allocations for RSpec examples.
			# @parameter scope [Object] The RSpec scope to apply profiling hooks to.
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
