# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

def initialize(...)
	super

	require_relative "../../lib/memory"
end

# Print a memory report.
#
# Accepts either a `Memory::Sampler` or `Memory::Report` as input.
#
# @parameter input [Memory::Report] The sampler or report to print.
def print(input:)
	# Convert Sampler to Report if needed:
	report = case input
	when Memory::Sampler
		input.report
	when Memory::Report
		input
	else
		raise ArgumentError, "Expected Memory::Sampler or Memory::Report, got #{input.class}"
	end
	
	report.print($stderr)

	return report
end
