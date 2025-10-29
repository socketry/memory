# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2025, by Samuel Williams.

require "memory"
require "stringio"
require "json"

describe Memory::Report do
	let(:report) do
		Memory.report do
			Array.new
			"Hello World".dup
		end
	end
	
	it "accepts options" do
		result = report.as_json(max_nesting: 1)
	end
	
	it "captures allocations" do
		result = report.as_json
		
		expect(result).to have_keys(
			total_allocated: be_a(Hash),
			total_retained: be_a(Hash),
			aggregates: be_a(Array),
		)
		
		expect(result[:total_allocated]).to have_keys(
			size: be_a(Integer),
			count: be_a(Integer),
		)
		
		expect(result[:total_retained]).to have_keys(
			size: be_a(Integer),
			count: be_a(Integer),
		)
		
		expect(result[:aggregates]).to have_attributes(size: be == 6)
	end
	
	with "custom report" do
		let(:report) do
			Memory::Report.new([
				Memory::Aggregate.new("By Gem", &:gem),
				Memory::Aggregate.new("By File", &:file),
				Memory::Aggregate.new("By Class", &:class_name),
			])
		end
		
		it "captures allocations" do
			Memory.capture(report) do
				Array.new
			end
			
			expect(report.aggregates).to have_attributes(size: be == 3)
		end
	end
	
	with "invalid UTF-8 strings" do
		let(:value_aggregate) do
			Memory::ValueAggregate.new("Strings By Value") {|allocation| allocation.class_name}
		end
		
		it "can safely convert to JSON" do
			# Create a cache for the allocation
			cache = Memory::Cache.new
			
			# Create an invalid UTF-8 byte sequence
			invalid_string = "\xff\xfe".dup.force_encoding("UTF-8")
			
			# Create an allocation with an invalid UTF-8 string value
			allocation = Memory::Allocation.new(
				cache,           # cache
				"String",        # class_name
				"test.rb",       # file
				42,              # line
				100,             # memsize
				invalid_string,  # value (invalid UTF-8)
				true             # retained
			)
			
			# Add the allocation to the value aggregate
			value_aggregate << allocation
			
			# This should not raise an error even with invalid UTF-8
			result = value_aggregate.as_json
			
			# Verify we can convert to JSON string
			json_string = JSON.generate(result)
			expect(json_string).to be_a(String)
		end
	end
	
	with "#print" do
		let(:io) {StringIO.new}
		
		it "prints retained memory profile header" do
			report = Memory::Report.new([], retained_only: true)
			report.print(io)
			output = io.string
			
			expect(output).to be =~ /# Retained Memory Profile/
		end
		
		it "prints memory profile header when not retained_only" do
			report = Memory::Report.new([], retained_only: false)
			report.print(io)
			output = io.string
			
			expect(output).to be =~ /# Memory Profile/
			expect(output).not.to be =~ /Retained Memory Profile/
		end
		
		it "prints total allocated and retained" do
			report = Memory::Report.new([])
			
			Memory.capture(report) do
				Array.new
				"Hello World".dup
			end
			
			report.print(io)
			output = io.string
			
			expect(output).to be =~ /Total Allocated:/
			expect(output).to be =~ /Total Retained:/
			expect(output).to be =~ /allocation/
		end
		
		it "prints all aggregates" do
			aggregates = [
				Memory::Aggregate.new("By Gem", &:gem),
				Memory::Aggregate.new("By Class", &:class_name),
			]
			report = Memory::Report.new(aggregates)
			
			Memory.capture(report) do
				Array.new
			end
			
			report.print(io)
			output = io.string
			
			expect(output).to be =~ /## By Gem/
			expect(output).to be =~ /## By Class/
		end
		
		it "formats memory sizes in human-readable format" do
			report = Memory::Report.new([])
			
			Memory.capture(report) do
				# Allocate enough to get KiB
				1000.times {"x" * 100}
			end
			
			report.print(io)
			output = io.string
			
			# Should show formatted bytes (KiB, not just B)
			expect(output).to be =~ /KiB/
		end
	end
	
	with "#add" do
		it "adds sampler allocations to the report" do
			report = Memory::Report.new([])
			sampler = Memory::Sampler.new
			
			sampler.run do
				Array.new
			end
			
			report.add(sampler)
			
			expect(report.total_allocated.count).to be > 0
		end
	end
	
	with "#concat" do
		it "accumulates allocations" do
			report = Memory::Report.new([])
			cache = Memory::Cache.new
			
			allocations = [
				Memory::Allocation.new(cache, "String", "test.rb", 1, 100, "test", true),
				Memory::Allocation.new(cache, "Array", "test.rb", 2, 200, nil, true),
			]
			
			report.concat(allocations)
			
			expect(report.total_allocated).to have_attributes(
				size: be == 300,
				count: be == 2
			)
		end
		
		it "tracks retained allocations separately" do
			report = Memory::Report.new([])
			cache = Memory::Cache.new
			
			allocations = [
				Memory::Allocation.new(cache, "String", "test.rb", 1, 100, "test", true),
				Memory::Allocation.new(cache, "Array", "test.rb", 2, 200, nil, false),
			]
			
			report.concat(allocations)
			
			expect(report.total_allocated).to have_attributes(
				size: be == 300,
				count: be == 2
			)
			
			expect(report.total_retained).to have_attributes(
				size: be == 100,
				count: be == 1
			)
		end
		
		it "only adds retained allocations to aggregates when retained_only is true" do
			aggregate = Memory::Aggregate.new("By Class", &:class_name)
			report = Memory::Report.new([aggregate], retained_only: true)
			cache = Memory::Cache.new
			
			allocations = [
				Memory::Allocation.new(cache, "String", "test.rb", 1, 100, "test", true),
				Memory::Allocation.new(cache, "Array", "test.rb", 2, 200, nil, false),
			]
			
			report.concat(allocations)
			
			# Aggregate should only have the retained allocation
			expect(aggregate.totals.size).to be == 1
			expect(aggregate.totals["String"]).to have_attributes(
				size: be == 100,
				count: be == 1
			)
		end
		
		it "adds all allocations to aggregates when retained_only is false" do
			aggregate = Memory::Aggregate.new("By Class", &:class_name)
			report = Memory::Report.new([aggregate], retained_only: false)
			cache = Memory::Cache.new
			
			allocations = [
				Memory::Allocation.new(cache, "String", "test.rb", 1, 100, "test", true),
				Memory::Allocation.new(cache, "Array", "test.rb", 2, 200, nil, false),
			]
			
			report.concat(allocations)
			
			# Aggregate should have both allocations
			expect(aggregate.totals.size).to be == 2
		end
	end
	
	with "#inspect" do
		it "returns a summary string" do
			report = Memory::Report.new([])
			
			Memory.capture(report) do
				Array.new
			end
			
			result = report.inspect
			
			expect(result).to be =~ /Memory::Report/
			expect(result).to be =~ /allocated/
			expect(result).to be =~ /retained/
		end
	end
	
	with "#to_json" do
		it "generates valid JSON string" do
			report = Memory::Report.new([])
			
			Memory.capture(report) do
				Array.new
			end
			
			json_string = report.to_json
			
			expect(json_string).to be_a(String)
			
			# Verify it's valid JSON by parsing it
			parsed = JSON.parse(json_string)
			expect(parsed).to be_a(Hash)
			expect(parsed).to have_keys("total_allocated", "total_retained", "aggregates")
		end
	end
	
	with ".general" do
		it "creates a report with standard aggregates" do
			report = Memory::Report.general
			
			expect(report).to be_a(Memory::Report)
			expect(report.aggregates).to have_attributes(size: be == 6)
		end
		
		it "includes expected aggregate types" do
			report = Memory::Report.general
			
			aggregate_titles = report.aggregates.map(&:title)
			
			expect(aggregate_titles).to be(:include?, "By Gem")
			expect(aggregate_titles).to be(:include?, "By File")
			expect(aggregate_titles).to be(:include?, "By Location")
			expect(aggregate_titles).to be(:include?, "By Class")
			expect(aggregate_titles).to be(:include?, "Strings By Gem")
			expect(aggregate_titles).to be(:include?, "Strings By Location")
		end
		
		it "passes options through" do
			report = Memory::Report.general(retained_only: false)
			cache = Memory::Cache.new
			
			allocations = [
				Memory::Allocation.new(cache, "String", "test.rb", 1, 100, "test", false),
			]
			
			report.concat(allocations)
			
			# With retained_only: false, non-retained allocations should be in aggregates
			expect(report.aggregates.first.total.count).to be > 0
		end
	end
end
