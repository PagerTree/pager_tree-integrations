module PagerTree::Integrations
  class Pulsetic::V3 < Integration
    OPTIONS = []
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    after_initialize do
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
      id = adapter_incoming_request_params.dig("monitor", "id")
      typ = _alert_type == "certificate_expires_soon" ? "certificate" : "monitor"
      "#{id}_#{typ}"
    end

    def adapter_action
      case _alert_type
      when "monitor_offline", "certificate_expires_soon"
        :create
      when "monitor_online"
        :resolve
      else
        :other
      end
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        thirdparty_id: adapter_thirdparty_id,
        additional_data: _additional_datums
      )
    end

    private

    def _title
      case _alert_type
      when "monitor_offline"
        "#{adapter_incoming_request_params.dig("monitor", "url")} OFFLINE"
      when "certificate_expires_soon"
        "#{adapter_incoming_request_params.dig("monitor", "url")} CERTIFICATE EXPIRES SOON"
      else
        "[PULSETIC] UNKNOWN ALERT TYPE"
      end
    end

    def _alert_type
      adapter_incoming_request_params.dig("alert_type")
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Monitor", value: "https://app.pulsetic.com/monitors/#{adapter_incoming_request_params.dig("monitor", "id")}/overview"),
        AdditionalDatum.new(format: "link", label: "URL", value: adapter_incoming_request_params.dig("monitor", "url"))
      ]
    end
  end
end
