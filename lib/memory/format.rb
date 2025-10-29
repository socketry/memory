# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Memory
	UNITS = {
		0 => "B",
		3 => "KiB",
		6 => "MiB",
		9 => "GiB",
		12 => "TiB",
		15 => "PiB",
		18 => "EiB",
		21 => "ZiB",
		24 => "YiB"
	}.freeze
	
	# Format bytes into human-readable units.
	# @parameter bytes [Integer] The number of bytes to format.
	# @returns [String] Formatted string with appropriate unit (e.g., "1.50 MiB").
	def self.formatted_bytes(bytes)
		return "0 B" if bytes.zero?
		
		scale = Math.log2(bytes).div(10) * 3
		scale = 24 if scale > 24
		"%.2f #{UNITS[scale]}" % (bytes / 10.0**scale)
	end
end
