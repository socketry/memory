# frozen_string_literal: true

require 'objspace'
require 'msgpack'

module MemoryProfiler
  class Wrapper < MessagePack::Factory
    def initialize(cache)
      super()
      
      @cache = cache
      
      self.register_type(0x01, Allocation,
        packer: ->(instance){self.pack(instance.pack)},
        unpacker: ->(data){Allocation.unpack(@cache, self.unpack(data))},
      )
      
      self.register_type(0x02, Symbol)
    end
  end
  
  Allocation = Struct.new(:cache, :class_name, :file, :line, :memsize, :string_value, :retained) do
    def location
      cache.lookup_location(file, line)
    end
    
    def gem
      cache.guess_gem(file)
    end
    
    def pack
      [class_name, file, line, memsize, string_value, retained]
    end
    
    def self.unpack(cache, fields)
      self.new(cache, *fields)
    end
  end
  
  # Reporter is the top level API used for generating memory reports.
  #
  # @example Measure object allocation in a block
  #   report = Reporter.report(top: 50) do
  #     5.times { "foo" }
  #   end
  class Reporter
    class << self
      attr_accessor :current_reporter
    end

    attr_reader :top, :trace, :allocated

    def initialize(opts = {})
      @top          = opts[:top] || 50
      @trace        = opts[:trace] && Array(opts[:trace])
      @ignore_files = opts[:ignore_files] && Regexp.new(opts[:ignore_files])
      @allow_files  = opts[:allow_files] && /#{Array(opts[:allow_files]).join('|')}/
      
      @cache = Cache.new
      @wrapper = Wrapper.new(@cache)
      @allocated = []
    end

    # Helper for generating new reporter and running against block.
    # @param [Hash] opts the options to create a report with
    # @option opts :top max number of entries to output
    # @option opts :trace a class or an array of classes you explicitly want to trace
    # @option opts :ignore_files a regular expression used to exclude certain files from tracing
    # @option opts :allow_files a string or array of strings to selectively include in tracing
    # @return [MemoryProfiler::Results]
    def self.report(opts = {}, &block)
      self.new(opts).run(&block)
    end

    def start
      GC.disable
      GC.start

      @generation = GC.count
      ObjectSpace.trace_object_allocations_start
    end

    def stop
      ObjectSpace.trace_object_allocations_stop
      allocated = track_allocations(@generation)
      $stderr.puts
      $stderr.puts "(Got allocated list: #{allocated.size}, Allocated object count: #{ObjectSpace.count_objects.inspect})"
      $stderr.puts

      GC.enable
      3.times{GC.start}

      $stderr.puts "(Retained object count: #{ObjectSpace.count_objects.inspect})"

      # Caution: Do not allocate any new Objects between the call to GC.start and the completion of the retained lookups. It is likely that a new Object would reuse an object_id from a GC'd object.

      ObjectSpace.each_object do |obj|
        next unless ObjectSpace.allocation_generation(obj) == @generation
        
        if found = allocated[obj.__id__]
          found.retained = true
        end
      end

      ObjectSpace.trace_object_allocations_clear
    end

    def dump(io = nil)
      $stderr.puts "(Dumping allocations: #{@allocated.size})"
      
      if io
        packer = @wrapper.packer(io)
        packer.pack(@allocated)
        packer.flush
      else
        @wrapper.dump(@allocated)
      end
    end
    
    def load(data)
      allocations = @wrapper.load(data)
      
      $stderr.puts "(Loading allocations: #{allocations.size})"
      
      @allocated.concat(allocations)
    end

    def results
      results = Results.new
      results.register_results(@allocated, @top)
    end

    # Collects object allocation and memory of ruby code inside of passed block.
    def run(&block)
      start
      
      begin
        return yield
      ensure
        stop
      end
    end

    private

    # Iterates through objects in memory of a given generation.
    # Stores results along with meta data of objects collected.
    def track_allocations(generation)
      rvalue_size = GC::INTERNAL_CONSTANTS[:RVALUE_SIZE]
      index = 0

      allocated = Hash.new.compare_by_identity

      ObjectSpace.each_object do |obj|
        next unless ObjectSpace.allocation_generation(obj) == generation

        file = ObjectSpace.allocation_sourcefile(obj) || "(no name)"
        next if @ignore_files && @ignore_files =~ file
        next if @allow_files && !(@allow_files =~ file)

        klass = obj.class rescue nil
        unless Class === klass
          # attempt to determine the true Class when .class returns something other than a Class
          klass = Kernel.instance_method(:class).bind(obj).call
        end
        next if @trace && !trace.include?(klass)

        line = ObjectSpace.allocation_sourceline(obj)

        # we do memsize first to avoid freezing as a side effect and shifting
        # storage to the new frozen string, this happens on @hash[s] in lookup_string
        memsize = ObjectSpace.memsize_of(obj)
        class_name = @cache.lookup_class_name(klass)
        string_value = (klass == String) ? @cache.lookup_string(obj) : nil

        # compensate for API bug
        memsize = rvalue_size if memsize > 100_000_000_000

        allocation = Allocation.new(@cache, class_name, file, line, memsize, string_value, false)

        @allocated << allocation
        allocated[obj.__id__] = allocation
      end

      return allocated
    end
  end
end
