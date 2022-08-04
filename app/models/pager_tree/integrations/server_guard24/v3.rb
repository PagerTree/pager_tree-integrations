module PagerTree::Integrations
  class ServerGuard24::V3 < Integration
    OPTIONS = [
      {key: :resolve_warn, type: :boolean, default: false}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    validates :option_resolve_warn, inclusion: {in: [true, false]}

    after_initialize do
      self.option_resolve_warn ||= false
    end

    def adapter_supports_incoming?
      true
    end

    def adapter_supports_outgoing?
      false
    end

    def adapter_incoming_can_defer?
      true
    end

    def adapter_thirdparty_id
      [adapter_incoming_request_params.dig("server_name"), adapter_incoming_request_params.dig("service_shortname")].compact_blank.join("_")
    end

    def adapter_action
      check_result = adapter_incoming_request_params.dig("check_result")

      if check_result == "CRITICAL"
        :create
      elsif check_result == "OK" || (check_result == "WARNING" && self.option_resolve_warn == true)
        :resolve
      else
        :other
      end
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        description: _description,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [adapter_thirdparty_id],
        additional_data: _additional_datums
      )
    end

    private

    def _title
      "#{adapter_incoming_request_params.dig("server_name")} is DOWN"
    end

    def _description
      "#{adapter_incoming_request_params.dig("server_name")} is DOWN because #{adapter_incoming_request_params.dig("check_output")}"
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "text", label: "Server Name", value: adapter_incoming_request_params.dig("server_name")),
        AdditionalDatum.new(format: "text", label: "Server Address", value: adapter_incoming_request_params.dig("server_address")),
        AdditionalDatum.new(format: "text", label: "Service Name", value: adapter_incoming_request_params.dig("service_name")),
        AdditionalDatum.new(format: "text", label: "Service Short Name", value: adapter_incoming_request_params.dig("service_shortname")),
        AdditionalDatum.new(format: "datetime", label: "Notification Time", value: adapter_incoming_request_params.dig("notification_time")),
        AdditionalDatum.new(format: "text", label: "Check Result", value: adapter_incoming_request_params.dig("check_result")),
        AdditionalDatum.new(format: "text", label: "Check Output", value: adapter_incoming_request_params.dig("check_output"))
      ]
    end
  end
end
