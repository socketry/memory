# frozen_string_literal: true

require_relative "memory/version"
require_relative "memory/cache"
require_relative "memory/report"
require_relative "memory/sampler"

module Memory
  def self.report(opts = {}, &block)
    Reporter.report(opts, &block)
  end

  def self.start(opts = {})
    unless Reporter.current_reporter
      Reporter.current_reporter = Reporter.new(opts)
      Reporter.current_reporter.start
    end
  end

  def self.stop
    Reporter.current_reporter.stop if Reporter.current_reporter
  ensure
    Reporter.current_reporter = nil
  end
end
