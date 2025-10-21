# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require "memory"

describe Memory do
	it "has a version number" do
		expect(Memory::VERSION).to be =~ /\d+\.\d+\.\d+/
	end
end
