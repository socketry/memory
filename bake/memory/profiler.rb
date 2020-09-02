# frozen_string_literal: true

def check
	require 'console'
	
	paths = Dir["../../*.mprof"]
	
	total_size = paths.sum{|path| File.size(path)}
	
	require_relative 'lib/memory_profiler'
	
	report = Memory::Report.general
	
	cache = Memory::Cache.new
	wrapper = Memory::Wrapper.new(cache)
	
	measure = Console.logger.measure(report, total_size)
	
	paths.each do |path|
		Console.logger.info(report, "Loading #{path}, #{Memory.formatted_bytes File.size(path)}")
		
		File.open(path) do |io|
			unpacker = wrapper.unpacker(io)
			count = unpacker.read_array_header
			
			report.concat(unpacker)
			
			measure.increment(io.size)
		end
		
		Console.logger.info(report, "Loaded allocations, #{report.total_allocated}")
	end
	
	report.print($stdout)
	
	binding.irb
end