# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2013-2019, by Sam Saffron.
# Copyright, 2014, by Søren Skovsbøll.
# Copyright, 2017, by Nick LaMuro.
# Copyright, 2018, by Jonas Peschla.
# Copyright, 2020-2025, by Samuel Williams.

require_relative "memory/version"
require_relative "memory/cache"
require_relative "memory/report"
require_relative "memory/sampler"
require_relative "memory/usage"
require_relative "memory/graph"

# Memory profiler for Ruby applications.
# Provides tools to track and analyze memory allocations and retention.
module Memory
	# Capture memory allocations from a block of code.
	# @parameter report [Report | Nil] Optional report instance to add samples to.
	# @parameter block [Block] The code to profile.
	# @returns [Report] A report containing allocation statistics.
	def self.capture(report = nil, &block)
		sampler = Sampler.new
		sampler.run(&block)
		
		report ||= Report.general
		report.add(sampler)
		
		return report
	end
	
	# Generate a memory allocation report for a block of code.
	# @parameter block [Block] The code to profile.
	# @returns [Report] A report containing allocation statistics.
	def self.report(&block)
		self.capture(&block)
	end
end
