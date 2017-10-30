module ActionController
  module Instrumentation
    def process_action(*args)
      raw_payload = {
          :controller => self.class.name,
          :action     => self.action_name,
          :params     => request.filtered_parameters,
          :ip         => request.remote_ip,
          :format     => request.format.try(:ref),
          :method     => request.method,
          :path       => (request.fullpath rescue "unknown")
      }

      Stasher.add_default_fields_to_scope(Stasher::CurrentScope.fields, request)

      if self.respond_to?(:stasher_add_custom_fields_to_scope)
        stasher_add_custom_fields_to_scope(Stasher::CurrentScope.fields)
      end

      ActiveSupport::Notifications.instrument("start_processing.action_controller", raw_payload.dup)

      ActiveSupport::Notifications.instrument("process_action.action_controller", raw_payload) do |payload|
        result = super
        payload[:status] = response.status
        payload[:response] = response.body
        append_info_to_payload(payload)
        result
      end
    end

  end
end
