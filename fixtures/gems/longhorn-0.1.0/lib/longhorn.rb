# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2014, by Søren Skovsbøll.
# Copyright, 2014-2019, by Sam Saffron.
# Copyright, 2018, by Jonas Peschla.
# Copyright, 2020-2025, by Samuel Williams.

require "set"

module Longhorn
	def self.run
		result = Set.new
		["allocated", "retained"]
						.product(["memory", "objects"])
						.product(["gem", "file", "location", "class"])
						.each do |(type, metric), name|
							result << "#{type} #{metric} by #{name}"
						end
		result
	end
end
