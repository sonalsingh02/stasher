require 'logger'

class MockLogger < ::Logger
  def initialize(device = nil)
    super(device)
    @messages = []
  end

  attr_reader :messages

  def reset!
    @messages = []
  end

  def add(severity, message = nil, progname = nil, &block)
    @messages << { severity: severity, message: message }
  end
end