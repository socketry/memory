# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "memory/aggregate"
require "stringio"
require "json"

# Mock allocation class for testing
class MockAllocation
	def initialize(size:, count: 1, gem: nil, file: nil, class_name: nil, value: nil)
		@size = size
		@count = count
		@gem = gem
		@file = file
		@class_name = class_name
		@value = value
	end
	
	attr_reader :size, :count, :gem, :file, :class_name, :value
	
	def memsize
		@size
	end
end

describe Memory::Aggregate do
	let(:aggregate) {subject.new("By Gem", &:gem)}
	
	with "basic functionality" do
		it "has a title" do
			expect(aggregate.title).to be == "By Gem"
		end
		
		it "starts with zero total" do
			expect(aggregate.total).to have_attributes(
				size: be == 0,
				count: be == 0
			)
		end
		
		it "has empty totals" do
			expect(aggregate.totals.size).to be == 0
		end
	end
	
	with "#<<" do
		it "accumulates allocations by metric" do
			allocation1 = MockAllocation.new(size: 100, gem: "foo")
			allocation2 = MockAllocation.new(size: 200, gem: "foo")
			allocation3 = MockAllocation.new(size: 300, gem: "bar")
			
			aggregate << allocation1
			aggregate << allocation2
			aggregate << allocation3
			
			expect(aggregate.total).to have_attributes(
				size: be == 600,
				count: be == 3
			)
			
			expect(aggregate.totals).to have_attributes(
				size: be == 2
			)
			
			expect(aggregate.totals["foo"]).to have_attributes(
				size: be == 300,
				count: be == 2
			)
			
			expect(aggregate.totals["bar"]).to have_attributes(
				size: be == 300,
				count: be == 1
			)
		end
	end
	
	with "#totals_by" do
		it "sorts by memory size" do
			aggregate << MockAllocation.new(size: 100, gem: "small")
			aggregate << MockAllocation.new(size: 500, gem: "large")
			aggregate << MockAllocation.new(size: 300, gem: "medium")
			
			sorted = aggregate.totals_by(:size)
			
			expect(sorted.map(&:first)).to be == ["small", "medium", "large"]
		end
		
		it "sorts by count" do
			aggregate << MockAllocation.new(size: 100, gem: "one")
			aggregate << MockAllocation.new(size: 50, gem: "three")
			aggregate << MockAllocation.new(size: 50, gem: "three")
			aggregate << MockAllocation.new(size: 50, gem: "three")
			aggregate << MockAllocation.new(size: 75, gem: "two")
			aggregate << MockAllocation.new(size: 75, gem: "two")
			
			sorted = aggregate.totals_by(:count)
			
			expect(sorted.map(&:first)).to be == ["one", "two", "three"]
		end
	end
	
	with "#print" do
		let(:io) {StringIO.new}
		
		it "prints heading with title and total" do
			aggregate << MockAllocation.new(size: 1024, gem: "test")
			
			aggregate.print(io, limit: 10)
			output = io.string
			
			expect(output).to be =~ /## By Gem/
			expect(output).to be =~ /1.00 KiB/
			expect(output).to be =~ /1 allocation/
		end
		
		it "prints top allocations sorted by memory" do
			aggregate << MockAllocation.new(size: 100, gem: "small")
			aggregate << MockAllocation.new(size: 1000, gem: "large")
			aggregate << MockAllocation.new(size: 500, gem: "medium")
			
			aggregate.print(io, limit: 10)
			output = io.string
			
			# Should be sorted by size (largest first)
			lines = output.split("\n").grep(/^- /)
			expect(lines[0]).to be =~ /large/
			expect(lines[1]).to be =~ /medium/
			expect(lines[2]).to be =~ /small/
		end
		
		it "respects limit parameter" do
			5.times do |i|
				aggregate << MockAllocation.new(size: (i + 1) * 100, gem: "gem#{i}")
			end
			
			aggregate.print(io, limit: 3)
			output = io.string
			
			# Should only show top 3
			lines = output.split("\n").grep(/^- /)
			expect(lines).to have_attributes(size: be == 3)
			
			# Should show the largest ones
			expect(lines[0]).to be =~ /gem4/
			expect(lines[1]).to be =~ /gem3/
			expect(lines[2]).to be =~ /gem2/
		end
		
		it "uses custom title when provided" do
			aggregate.print(io, title: "Custom Title")
			output = io.string
			
			expect(output).to be =~ /Custom Title/
			expect(output).not.to be =~ /By Gem/
		end
		
		it "uses custom heading level" do
			aggregate.print(io, level: 3)
			output = io.string
			
			expect(output).to be =~ /^### By Gem/
		end
		
		it "includes metric names in output" do
			aggregate << MockAllocation.new(size: 100, gem: "my-gem")
			aggregate << MockAllocation.new(size: 200, gem: "other-gem")
			
			aggregate.print(io)
			output = io.string
			
			expect(output).to be =~ /my-gem/
			expect(output).to be =~ /other-gem/
		end
	end
	
	with "#as_json" do
		it "returns a hash representation" do
			aggregate << MockAllocation.new(size: 100, gem: "test")
			
			result = aggregate.as_json
			
			expect(result).to have_keys(
				:title,
				:total,
				:totals
			)
			
			expect(result[:title]).to be == "By Gem"
			expect(result[:total]).to be_a(Hash)
			expect(result[:totals]).to be_a(Array)
		end
	end
end

describe Memory::ValueAggregate do
	let(:value_aggregate) {subject.new("Strings By Value", &:class_name)}
	
	with "#<<" do
		it "groups allocations by value" do
			alloc1 = MockAllocation.new(size: 100, class_name: "String", value: "hello")
			alloc2 = MockAllocation.new(size: 200, class_name: "String", value: "hello")
			alloc3 = MockAllocation.new(size: 300, class_name: "String", value: "world")
			
			value_aggregate << alloc1
			value_aggregate << alloc2
			value_aggregate << alloc3
			
			expect(value_aggregate.aggregates).to have_attributes(
				size: be == 2
			)
			
			expect(value_aggregate.aggregates["hello"]).to be_a(Memory::Aggregate)
			expect(value_aggregate.aggregates["world"]).to be_a(Memory::Aggregate)
		end
		
		it "skips allocations without values" do
			alloc = MockAllocation.new(size: 100, class_name: "String", value: nil)
			
			value_aggregate << alloc
			
			expect(value_aggregate.aggregates.size).to be == 0
		end
	end
	
	with "#aggregates_by" do
		it "sorts aggregates by total memory" do
			value_aggregate << MockAllocation.new(size: 100, class_name: "String", value: "small")
			value_aggregate << MockAllocation.new(size: 500, class_name: "String", value: "large")
			value_aggregate << MockAllocation.new(size: 300, class_name: "String", value: "medium")
			
			sorted = value_aggregate.aggregates_by(:memory)
			
			expect(sorted.map(&:first)).to be == ["small", "medium", "large"]
		end
	end
	
	with "#print" do
		let(:io) {StringIO.new}
		
		it "prints heading with title" do
			value_aggregate.print(io)
			output = io.string
			
			expect(output).to be =~ /## Strings By Value/
		end
		
		it "prints sub-aggregates" do
			value_aggregate << MockAllocation.new(size: 100, class_name: "String", value: "hello")
			value_aggregate << MockAllocation.new(size: 200, class_name: "String", value: "world")
			
			value_aggregate.print(io)
			output = io.string
			
			# Should have nested headings for each value
			expect(output).to be =~ /### "hello"/
			expect(output).to be =~ /### "world"/
		end
		
		it "respects limit parameter" do
			5.times do |i|
				value_aggregate << MockAllocation.new(size: 100, class_name: "String", value: "value#{i}")
			end
			
			value_aggregate.print(io, limit: 3)
			output = io.string
			
			# Should only show top 3 value aggregates
			headers = output.scan(/^### /).count
			expect(headers).to be == 3
		end
	end
	
	with "#as_json" do
		it "returns a hash representation" do
			value_aggregate << MockAllocation.new(size: 100, class_name: "String", value: "test")
			
			result = value_aggregate.as_json
			
			expect(result).to have_keys(
				:title,
				:aggregates
			)
			
			expect(result[:title]).to be == "Strings By Value"
			expect(result[:aggregates]).to be_a(Array)
		end
		
		it "handles non-UTF8 keys safely" do
			# Create a value with invalid UTF-8
			binary_value = "\xFF\xFE".b
			alloc = MockAllocation.new(size: 100, class_name: "String", value: binary_value)
			
			value_aggregate << alloc
			result = value_aggregate.as_json
			
			# Should not raise an error when converting to JSON
			expect(result[:aggregates]).to be_a(Array)
			
			# Verify we can actually serialize to JSON
			json_string = JSON.generate(result)
			expect(json_string).to be_a(String)
		end
	end
end
