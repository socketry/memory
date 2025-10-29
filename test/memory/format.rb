# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "memory/format"

describe Memory do
	with ".formatted_bytes" do
		it "formats zero bytes" do
			expect(Memory.formatted_bytes(0)).to be == "0 B"
		end
		
		it "formats bytes" do
			expect(Memory.formatted_bytes(1)).to be == "1.00 B"
			expect(Memory.formatted_bytes(512)).to be == "512.00 B"
			expect(Memory.formatted_bytes(1023)).to be == "1023.00 B"
		end
		
		it "formats kibibytes (1024 bytes)" do
			expect(Memory.formatted_bytes(1024)).to be == "1.00 KiB"
			expect(Memory.formatted_bytes(1536)).to be == "1.50 KiB"
			expect(Memory.formatted_bytes(2048)).to be == "2.00 KiB"
			expect(Memory.formatted_bytes(1024 * 512)).to be == "512.00 KiB"
		end
		
		it "formats mebibytes (1024^2 bytes)" do
			expect(Memory.formatted_bytes(1024**2)).to be == "1.00 MiB"
			expect(Memory.formatted_bytes(1024**2 * 1.5)).to be == "1.50 MiB"
			expect(Memory.formatted_bytes(1024**2 * 100)).to be == "100.00 MiB"
		end
		
		it "formats gibibytes (1024^3 bytes)" do
			expect(Memory.formatted_bytes(1024**3)).to be == "1.00 GiB"
			expect(Memory.formatted_bytes(1024**3 * 2.5)).to be == "2.50 GiB"
		end
		
		it "formats tebibytes (1024^4 bytes)" do
			expect(Memory.formatted_bytes(1024**4)).to be == "1.00 TiB"
			expect(Memory.formatted_bytes(1024**4 * 5)).to be == "5.00 TiB"
		end
		
		it "formats pebibytes (1024^5 bytes)" do
			expect(Memory.formatted_bytes(1024**5)).to be == "1.00 PiB"
		end
		
		it "formats exbibytes (1024^6 bytes)" do
			expect(Memory.formatted_bytes(1024**6)).to be == "1.00 EiB"
		end
		
		it "formats zebibytes (1024^7 bytes)" do
			expect(Memory.formatted_bytes(1024**7)).to be == "1.00 ZiB"
		end
		
		it "formats yobibytes (1024^8 bytes)" do
			expect(Memory.formatted_bytes(1024**8)).to be == "1.00 YiB"
		end
		
		it "caps at yobibytes for very large values" do
			# Anything larger than 1024^8 should still show as YiB
			expect(Memory.formatted_bytes(1024**9)).to be == "1024.00 YiB"
		end
	end
end
