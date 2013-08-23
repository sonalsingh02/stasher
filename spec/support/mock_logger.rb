##
# A standard Logger that logs messages to an array (accessible as #messages)
class MockLogger < ::Logger
  def initialize(log_level = ::Logger::WARN)
    super(nil)
    @messages = []
    self.level = log_level
  end

  attr_reader :messages

  def reset!
    @messages = []
  end

  def <<(message)
    @messages << message
  end
end