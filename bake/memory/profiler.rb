# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2013-2018, by Sam Saffron.
# Copyright, 2014, by Richard Schneeman.
# Copyright, 2018, by Jonas Peschla.
# Copyright, 2020-2022, by Samuel Williams.

def check(paths:)
	require "console"
	
	total_size = paths.sum{|path| File.size(path)}
	
	require_relative "../../lib/memory"
	
	report = Memory::Report.general
	
	cache = Memory::Cache.new
	wrapper = Memory::Wrapper.new(cache)
	
	progress = Console.logger.progress(report, total_size)
	
	paths.each do |path|
		Console.logger.info(report, "Loading #{path}, #{Memory.formatted_bytes File.size(path)}")
		
		File.open(path) do |io|
			unpacker = wrapper.unpacker(io)
			count = unpacker.read_array_header
			
			report.concat(unpacker)
			
			progress.increment(io.size)
		end
		
		Console.logger.info(report, "Loaded allocations, #{report.total_allocated}")
	end
	
	report.print($stdout)
end
