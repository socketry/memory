# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

def initialize(...)
	super
	
	require_relative '../../lib/memory'
end

# Load a sampler from one or more .mprof files.
#
# Multiple files will be combined into a single sampler, useful for
# analyzing aggregated profiling data.
#
# @parameter paths [Array(String)] Paths to .mprof files.
# @returns [Memory::Sampler] The loaded sampler with all allocations.
def load(paths:)
	sampler = Memory::Sampler.new
	cache = sampler.cache
	wrapper = sampler.wrapper
	
	total_size = paths.sum{|path| File.size(path)}
	progress = Console.logger.progress(sampler, total_size)
	
	paths.each do |path|
		Console.logger.info(sampler, "Loading #{path}, #{Memory.formatted_bytes File.size(path)}")
		
		File.open(path, 'r', encoding: Encoding::BINARY) do |io|
			unpacker = wrapper.unpacker(io)
			count = unpacker.read_array_header
			
			last_pos = 0
			
			# Read allocations directly into the sampler's array:
			unpacker.each do |allocation|
				sampler.allocated << allocation
				
				# Update progress based on bytes read:
				current_pos = io.pos
				progress.increment(current_pos - last_pos)
				last_pos = current_pos
			end
		end
		
		Console.logger.info(sampler, "Loaded #{sampler.allocated.size} allocations")
	end
	
	return sampler
end

# Dump a sampler to a .mprof file.
#
# @parameter input [Memory::Sampler] The sampler to dump.
# @parameter output [String] Path to write the .mprof file.
# @returns [Memory::Sampler] The input sampler.
def dump(path, input:)
	File.open(path, 'w', encoding: Encoding::BINARY) do |io|
		input.dump(io)
	end
	
	Console.logger.info(self, "Saved sampler to #{path} (#{File.size(path)} bytes)")
	
	return input
end

# Load a sampler from an ObjectSpace heap dump.
#
# @parameter path [String] Path to the heap dump JSON file.
# @returns [Memory::Sampler] A sampler populated with allocations from the heap dump.
def load_object_space_dump(path)
	file_size = File.size(path)
	progress = Console.logger.progress(self, file_size)
	
	Console.logger.info(self, "Loading heap dump from #{path} (#{Memory.formatted_bytes(file_size)})")
	
	sampler = nil
	File.open(path, 'r') do |io|
		sampler = Memory::Sampler.load_object_space_dump(io) do |line_count, object_count|
			# Update progress based on bytes read:
			progress.increment(io.pos - progress.current)
		end
	end
	
	Console.logger.info(self, "Loaded #{sampler.allocated.size} objects from heap dump")
	
	return sampler
end
