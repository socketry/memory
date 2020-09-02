# Memory

A set of tools for profiling memory in Ruby.

[![Development Status](https://github.com/socketry/memory/workflows/Development/badge.svg)](https://github.com/socketry/memory/actions?workflow=Development)

## Features

- Fast memory capture for million+ allocations.
- Persist results to disk for vast aggregations and comparisons over time.

## Installation

Add this line to your application's Gemfile:

~~~ shell
$ bundle add 'memory'
~~~

## Usage

``` ruby
require 'memory'

report = Memory.report do
	# run your code here
end

report.print
```

Or, you can use the `.start`/`.stop` methods as well:

~~~ ruby
require 'memory'

sampler = Memory::Sampler.new

sampler.start
# run your code here
sampler.stop

report = sampler.report
report.print
~~~

### RSpec Integration

~~~ ruby
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
		memory_sampler.load(File.read(
			path,
			encoding: Encoding::BINARY,
		))
	end
	
	memory_sampler.results.print
end
~~~

#### Raw Object Allocations

~~~ ruby
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
~~~

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

## License

Copyright, 2020, by [Samuel G. D. Williams](https://www.codeotaku.com).

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
