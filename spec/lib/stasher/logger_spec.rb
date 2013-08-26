require 'spec_helper'

describe Stasher::Logger do
  subject (:logger) { Stasher::Logger.new }

  before :each do
    logger.level = ::Logger::WARN
  end

  it "logs messages that are at the configured level" do
    Stasher.should_receive(:log).with('WARN', 'message')

    logger.warn 'message'
  end

  it "logs messages that are above the configured level" do
    Stasher.should_receive(:log).with('ERROR', 'message')

    logger.error 'message'
  end

  it "does not log messages that are below the configured level" do
    Stasher.should_not_receive(:log)

    logger.info 'message'
  end

  it "formats the severity" do
    Stasher.should_receive(:log).with('WARN', 'message')

    logger.add ::Logger::WARN, "message"
  end

  it "returns true" do
    Stasher.stub(:log)

    logger.add( ::Logger::WARN, "message" ).should be_true
  end

  context "when there is a block given" do
    it "yields to the block" do
      Stasher.stub(:log)

      expect { |b|
        logger.add ::Logger::WARN, &b
      }.to yield_with_no_args
    end

    it "logs the returned message" do
      Stasher.should_receive(:log).with('WARN', 'message')

      logger.add ::Logger::WARN do
        "message"
      end      
    end
  end

  context "when the message is a string" do    
    it "formats the message" do
      logger.should_receive(:format_message).with(::Logger::WARN, an_instance_of(Time), nil, "message").and_return("formatted")
      Stasher.stub(:log)

      logger.warn 'message'
    end

    it "renders the formatted message" do
      logger.stub(:format_message).and_return("formatted")
      Stasher.should_receive(:log).with('WARN', 'formatted')

      logger.warn 'message'
    end
  end

  context "when the message is an object" do
    let (:message) { Object.new }

    it "does not format the message" do
      logger.should_not_receive(:format_message)
      Stasher.stub(:log)

      logger.warn message
    end

    it "logs the raw message object" do
      Stasher.should_receive(:log).with('WARN', message)

      logger.warn message
    end
  end
end