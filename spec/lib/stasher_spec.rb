require 'spec_helper'

describe Stasher do
  describe "when removing Rails' log subscribers" do
    after do
      ActionController::LogSubscriber.attach_to :action_controller
      ActionView::LogSubscriber.attach_to :action_view
    end

    it "should remove subscribers for controller events" do
      expect {
        Stasher.remove_existing_log_subscriptions
      }.to change {
        ActiveSupport::Notifications.notifier.listeners_for('process_action.action_controller')
      }
    end

    it "should remove subscribers for all events" do
      expect {
        Stasher.remove_existing_log_subscriptions
      }.to change {
        ActiveSupport::Notifications.notifier.listeners_for('render_template.action_view')
      }
    end

    it "shouldn't remove subscribers that aren't from Rails" do
      blk = -> {}
      ActiveSupport::Notifications.subscribe("process_action.action_controller", &blk)
      Stasher.remove_existing_log_subscriptions
      listeners = ActiveSupport::Notifications.notifier.listeners_for('process_action.action_controller')
      listeners.size.should > 0
    end
  end

  describe '.add_default_fields_to_scope' do
    let(:scope) { {} }
    let(:request) { double(:params => {}, :remote_ip => '10.0.0.1', :uuid => "uuid" )}
    
    it 'appends default parameters to payload' do
      Stasher.add_default_fields_to_scope(scope, request)
      
      scope.should == { :uuid => "uuid" }
    end
  end

  describe '.append_custom_params' do
    let(:block) { ->{} }
    it 'defines a method in ActionController::Base' do
      ActionController::Base.should_receive(:send).with(:define_method, :stasher_add_custom_fields_to_scope, &block)
      Stasher.add_custom_fields(&block)
    end
  end

  describe '.setup' do
    let(:logger) { double }
    let(:stasher_config) { double(:logger => logger, :log_level => 'warn', attach_to: [:active_record] ) }
    let(:config) { double(:stasher => stasher_config) }
    let(:app) { double(:config => config) }
    before do
      config.stub(:action_dispatch => double(:rack_cache => false))
    end
    it 'defines a method in ActionController::Base' do
      Stasher.should_receive(:require).with('socket')
      Stasher.should_receive(:require).with('stasher/rails_ext/action_controller/metal/instrumentation')
      Stasher.should_receive(:require).with('logstash/event')
      Stasher.should_receive(:suppress_app_logs).with(app)
      Stasher::RequestLogSubscriber.should_receive(:attach_to).with(:active_record)
      logger.should_receive(:level=).with(::Logger::WARN)
      Stasher.setup(app)
      Stasher.enabled.should be_true
    end
  end

  describe '.suppress_app_logs' do
    let(:stasher_config){ double(:stasher => double(:suppress_app_log => true))}
    let(:app){ double(:config => stasher_config)}
    it 'removes existing subscriptions if enabled' do
      Stasher.should_receive(:require).with('stasher/rails_ext/rack/logger')
      Stasher.should_receive(:remove_existing_log_subscriptions)
      Stasher.suppress_app_logs(app)
    end

    context 'when disabled' do
      let(:stasher_config){ double(:stasher => double(:suppress_app_log => false)) }
      it 'does not remove existing subscription' do
        Stasher.should_not_receive(:remove_existing_log_subscriptions)
        Stasher.suppress_app_logs(app)
      end
    end
  end

  describe '.format_exception' do
    let(:type_name) { 'type' }
    let(:message) { 'message' }
    let(:backtrace) { 'backtrace' }

    it "returns a hash of exception details" do
      Stasher.format_exception(type_name, message, backtrace).should == {
        :exception => {
          :name => type_name,
          :message => message,
          :backtrace => backtrace
        }
      }
    end
  end

  describe '.log' do
    let(:logger) { double() }
    
    before :each do
      Stasher.logger = logger
      Stasher.source = "source"
      LogStash::Time.stub(:now => 'timestamp')
      Stasher::CurrentScope.fields = { :field => "value" }
    end

    it 'adds to log with specified level' do
      logger.should_receive(:send).with('warn?').and_return(true)
      logger.should_receive(:<<).with("{\"@source\":\"source\",\"@tags\":[\"log\",\"warn\"],\"@fields\":{\"severity\":\"WARN\",\"field\":\"value\"},\"@message\":\"WARNING\",\"@timestamp\":\"timestamp\"}\n")
      Stasher.log('warn', 'WARNING')
    end

    it 'includes the current scope fields' do


      Stasher.log('warn', 'WARNING')
    end
  end

  %w( fatal error warn info debug unknown ).each do |severity|
    describe ".#{severity}" do
      let(:message) { "This is a #{severity} message" }
      it 'should log with specified level' do
        Stasher.should_receive(:log).with(severity.to_sym, message)
        Stasher.send(severity, message )
      end
    end
  end
end