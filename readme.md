# Memory

A set of tools for profiling memory in Ruby.

[![Development Status](https://github.com/socketry/memory/workflows/Test/badge.svg)](https://github.com/socketry/memory/actions?workflow=Test)

## Features

  - Fast memory capture for million+ allocations.
  - Persist results to disk for vast aggregations and comparisons over time.

## Installation

Add this line to your application's Gemfile:

``` shell
$ bundle add 'memory'
```

## Usage

Please see the [project documentation](https://socketry.github.io/memory/) for more details.

  - [Getting Started](https://socketry.github.io/memory/guides/getting-started/index) - This guide explains how to get started with `memory`, a Ruby gem for profiling memory allocations in your applications.

### RSpec Integration

``` ruby
memory_sampler = nil
config.before(:all) do |example_group|
	name = example_group.class.description.gsub(/[^\w]+/, "-")
	path = "#{name}.mprof"
	
	skip if File.exist?(path)
	
	memory_sampler = Memory::Sampler.new
	memory_sampler.start
end

config.after(:all) do |example_group|
	name = example_group.class.description.gsub(/[^\w]+/, "-")
	path = "#{name}.mprof"
	
	if memory_sampler
		memory_sampler.stop
		
		File.open(path, "w", encoding: Encoding::BINARY) do |io|
			memory_sampler.dump(io)
		end
		
		memory_sampler = nil
	end
end

config.after(:suite) do
	memory_sampler = Memory::Sampler.new
	
	Dir.glob("*.mprof") do |path|
		$stderr.puts "Loading #{path}..."
		memory_sampler.load(File.read(path, encoding: Encoding::BINARY))
	end
	
	$stderr.puts "Memory usage:"
	memory_sampler.report.print
end
```

#### Raw Object Allocations

``` ruby
before = nil

config.before(:suite) do |example|
	3.times{GC.start}
	GC.disable
	before = ObjectSpace.count_objects
end

config.after(:suite) do |example|
	after = ObjectSpace.count_objects
	GC.enable
	
	$stderr.puts
	$stderr.puts "Object Allocations:"
	
	after.each do |key, b|
		a = before.fetch(key, 0)
		$stderr.puts "#{key}: #{a} -> #{b} = #{b-a} allocations"
	end
end
```

## Releases

Please see the [project releases](https://socketry.github.io/memory/releases/index) for all releases.

### v0.8.0

  - Removed old `RSpec` integration.
  - Introduced `Memory::Usage` and `Memory::Usage.of(object)` which recursively computes memory usage of an object and its contents.

### v0.7.1

  - Ensure aggregate keys are safe for serialization (and printing).

### v0.7.0

  - Add `Memory::Sampler#as_json` and `#to_json`.

### v0.6.0

  - Add agent context.

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
