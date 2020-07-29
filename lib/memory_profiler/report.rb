# frozen_string_literal: true

require_relative 'aggregate'

module MemoryProfiler
  class Report
    def self.general
      Report.new([
        Aggregate.new("By Gem", &:gem),
        Aggregate.new("By File", &:file),
        Aggregate.new("By Location", &:location),
        Aggregate.new("By Class", &:class_name),
        ValueAggregate.new("Strings By Gem", &:gem),
        ValueAggregate.new("Strings By Location", &:location),
      ])
    end
    
    def initialize(aggregates)
      @total_allocated = Aggregate::Total.new
      @total_retained = Aggregate::Total.new
      
      @aggregates = aggregates
    end
    
    attr :total_allocated
    
    def concat(allocations)
      allocations.each do |allocation|
        @total_allocated << allocation
        @total_retained << allocation if allocation.retained
        
        @aggregates.each do |aggregate|
          aggregate << allocation
        end
      end
    end

    def print(io = $stderr)
      io.puts "\# Memory Profile", nil
      
      io.puts "- Total Allocated: #{@total_allocated}"
      io.puts "- Total Retained: #{@total_retained}"
      io.puts
      
      @aggregates.each do |aggregate|
        aggregate.print(io)
      end
    end
  end
end
