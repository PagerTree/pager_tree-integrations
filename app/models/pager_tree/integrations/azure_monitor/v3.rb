module PagerTree::Integrations
  class AzureMonitor::V3 < Integration
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
      adapter_incoming_request_params.dig("data", "essentials", "alertId")
    end

    def adapter_action
      case _monitor_condition
      when "Fired" then :create
      when "Resolved" then :resolve
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

    def _monitor_condition
      adapter_incoming_request_params.dig("data", "essentials", "monitorCondition")
    end

    def _title
      adapter_incoming_request_params.dig("data", "essentials", "alertRule")
    end

    def _description
      adapter_incoming_request_params.dig("data", "essentials", "description")
    end

    def _urgency
      case adapter_incoming_request_params.dig("data", "essentials", "severity")
      when "Sev0" then "low"
      when "Sev1" then "low"
      when "Sev2" then "medium"
      when "Sev3" then "high"
      when "Sev4" then "critical"
      end
    end

    def _additional_datums
      essentials = adapter_incoming_request_params.dig("data", "essentials")
      [
        AdditionalDatum.new(format: "text", label: "Monitoring Service", value: essentials.dig("monitoringService")),
        AdditionalDatum.new(format: "text", label: "Alert Rule", value: essentials.dig("alertRule")),
        AdditionalDatum.new(format: "text", label: "Severity", value: essentials.dig("severity")),
        AdditionalDatum.new(format: "datetime", label: "Fired At", value: essentials.dig("firedDateTime"))
      ]
    end
  end
end
