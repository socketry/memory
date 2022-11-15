# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2013-2019, by Sam Saffron.
# Copyright, 2014, by Søren Skovsbøll.
# Copyright, 2017, by Nick LaMuro.
# Copyright, 2018, by Jonas Peschla.
# Copyright, 2020-2022, by Samuel Williams.

require_relative "memory/version"
require_relative "memory/cache"
require_relative "memory/report"
require_relative "memory/sampler"

module Memory
	def self.report(&block)
		sampler = Sampler.new
		sampler.run(&block)
		
		return sampler.report
	end
end
