# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Memory
	UNITS = ["B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"].freeze
	
	# Format bytes into human-readable units.
	# @parameter bytes [Integer] The number of bytes to format.
	# @returns [String] Formatted string with appropriate unit (e.g., "1.50 MiB").
	def self.formatted_bytes(bytes)
		return "0 B" if bytes.zero?
		
		# Calculate how many times we can divide by 1024 (2^10)
		# log2(bytes) / 10 gives the number of 1024 divisions
		index = Math.log2(bytes).to_i / 10
		index = 8 if index > 8  # Cap at YiB
		
		# Divide by 1024^index, which equals 2^(index * 10)
		"%.2f #{UNITS[index]}" % (bytes / (1024.0 ** index))
	end
end
