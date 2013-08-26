require 'rails/railtie'
require 'action_view/log_subscriber'
require 'action_controller/log_subscriber'

module Stasher
  class Railtie < Rails::Railtie
    config.stasher = ActiveSupport::OrderedOptions.new
    config.stasher.enabled = false
    config.stasher.suppress_app_log = true
    config.stasher.redirect_logger = false
    config.stasher.attach_to = [ :action_controller, :active_record]

    initializer 'stasher' do |app|
      Stasher.setup(app) if app.config.stasher.enabled
      Rails.logger = Stasher::Logger.new  if app.config.stasher.redirect_logger
    end
  end
end