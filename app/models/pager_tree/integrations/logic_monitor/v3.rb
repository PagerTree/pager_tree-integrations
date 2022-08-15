module PagerTree::Integrations
  class LogicMonitor::V3 < Integration
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
      adapter_incoming_request_params.dig("alertid")
    end

    def adapter_action
      alert_status = adapter_incoming_request_params.dig("alertstatus")
      case alert_status
      when "active", "test"
        :create
      when "clear"
        :resolve
      else
        :other
      end
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        description: _description,
        urgency: _urgency,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [adapter_thirdparty_id],
        additional_data: _additional_datums
      )
    end

    private

    def _title
      adapter_incoming_request_params.dig("eventmsg")
    end

    def _description
      adapter_incoming_request_params.dig("eventlogmsg")
    end

    def _urgency
      level = adapter_incoming_request_params.dig("level").to_s.downcase
      case level
      when "warn", "warning"
        "medium"
      when "error"
        "high"
      when "critical"
        "critical"
      end
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "text", label: "Host", value: adapter_incoming_request_params.dig("host")),
        AdditionalDatum.new(format: "text", label: "Service", value: adapter_incoming_request_params.dig("service"))
      ]
    end
  end
end
