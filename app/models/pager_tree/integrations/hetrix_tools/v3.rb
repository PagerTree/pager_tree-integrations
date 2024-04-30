module PagerTree::Integrations
  class HetrixTools::V3 < Integration
    OPTIONS = [
      {key: :authentication_token, type: :string, default: nil}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    after_initialize do
      self.option_authentication_token ||= nil
    end

    def adapter_should_block_incoming?(request)
      self.option_authentication_token.present? && (request.headers["Authorization"] != "Bearer #{self.option_authentication_token}")
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
      try("_adapter_thirdparty_id_#{_webhook_type}") || SecureRandom.hex(16)
    end

    def adapter_action
      try("_adapter_action_#{_webhook_type}") || :other
    end

    def _adapter_action_uptime
      case adapter_incoming_request_params.dig("monitor_status")
      when "online" then :resolve
      when "offline" then :create
      else
        :other
      end
    end

    def _adapter_action_blacklist
      :create
    end

    def _adapter_action_resource_usage
      :create
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        description: _description,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [],
        additional_data: _additional_datums
      )
    end

    def _adapter_thirdparty_id_uptime
      adapter_incoming_request_params.dig("monitor_id")
    end

    def _adapter_thirdparty_id_blacklist
      SecureRandom.hex(16)
    end

    def _adapter_thirdparty_id_resource_usage
      adapter_incoming_request_params.dig("monitor_id")
    end

    def _webhook_type
      @_webhook_type ||= if _webhook_type_uptime?
        :uptime
      elsif _webhook_type_resource_usage?
        :resource_usage
      elsif _webhook_type_blacklist?
        :blacklist
      else
        :unknown
      end
    end

    def _webhook_type_uptime?
      adapter_incoming_request_params.dig("monitor_errors").present?
    end

    def _webhook_type_blacklist?
      json = adapter_incoming_request_params.dig("_json")
      json.present? && json.is_a?(Array)
    end

    def _webhook_type_resource_usage?
      adapter_incoming_request_params.dig("resource_usage").present?
    end

    def _title
      try("_title_#{_webhook_type}") || "HetrixTools Alert"
    end

    def _title_uptime
      "#{adapter_incoming_request_params.dig("monitor_name")} is #{adapter_incoming_request_params.dig("monitor_status")}"
    end

    def _title_blacklist
      "Blacklist Alert"
    end

    def _title_resource_usage
      "#{adapter_incoming_request_params.dig("monitor_name")} usage alert"
    end

    def _description
      try("_description_#{_webhook_type}") || "No description provided"
    end

    def _description_uptime
      "<p>#{adapter_incoming_request_params.dig("monitor_target")} is #{adapter_incoming_request_params.dig("monitor_status")}</p>" +
        adapter_incoming_request_params.dig("monitor_errors").map { |k, v| "<p>#{k}: #{v}</p>" }.join("")
    end

    def _description_blacklist
      adapter_incoming_request_params.dig("_json").map { |x| "#{x["monitor"]} (#{x["blacklisted_now"]})" }.join("<br/>")
    end

    def _description_resource_usage
      [
        "<p>Resource Type: #{adapter_incoming_request_params.dig("resource_usage", "resource_type")}</p>",
        "<p>Current Usage: #{adapter_incoming_request_params.dig("resource_usage", "current_usage")}</p>",
        "<p>Average Usage: #{adapter_incoming_request_params.dig("resource_usage", "average_usage")} / #{adapter_incoming_request_params.dig("resource_usage", "average_minutes")}m</p>"
      ].join("")
    end

    def _additional_datums
      try("_additional_datums_#{_webhook_type}") || []
    end

    def _additional_datums_uptime
      [
        AdditionalDatum.new(format: "datetime", label: "Timestamp", value: Time.at(adapter_incoming_request_params.dig("timestamp"))),
        AdditionalDatum.new(format: "text", label: "Monitor Type", value: adapter_incoming_request_params.dig("monitor_type")),
        AdditionalDatum.new(format: "link", label: "Monitor Target", value: adapter_incoming_request_params.dig("monitor_target"))
      ]
    end

    def _additional_datums_blacklist
      []
    end

    def _additional_datums_resource_usage
      [
        AdditionalDatum.new(format: "text", label: "Resource Type", value: adapter_incoming_request_params.dig("resource_usage", "resource_type")),
        AdditionalDatum.new(format: "text", label: "Current Usage", value: adapter_incoming_request_params.dig("resource_usage", "current_usage"))
      ]
    end
  end
end
