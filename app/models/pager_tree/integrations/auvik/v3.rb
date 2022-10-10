module PagerTree::Integrations
  class Auvik::V3 < Integration
    AUVIK_SEVERITY = {
      emergency: 1,
      critical: 2,
      warning: 3,
      info: 4
    }

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
      _correlation_id
    end

    def adapter_action
      case _alert_status
      when 0 then :create
      when 1 then :resolve
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
        dedup_keys: [],
        additional_data: _additional_datums
      )
    end

    private

    def _correlation_id
      adapter_incoming_request_params.dig("correlationId")
    end

    def _alert_status
      adapter_incoming_request_params.dig("alertStatus")
    end

    def _title
      adapter_incoming_request_params.dig("alertName")
    end

    def _description
      adapter_incoming_request_params.dig("alertDescription")
    end

    def _urgency
      case adapter_incoming_request_params.dig("alertSeverity")
      when AUVIK_SEVERITY[:info] then "low"
      when AUVIK_SEVERITY[:warning] then "medium"
      when AUVIK_SEVERITY[:critical] then "high"
      when AUVIK_SEVERITY[:emergency] then "critical"
      else
        nil
      end
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "URL", value: adapter_incoming_request_params.dig("link")),
        AdditionalDatum.new(format: "text", label: "Alert Severity", value: adapter_incoming_request_params.dig("alertSeverityString")),
        AdditionalDatum.new(format: "text", label: "Correlation ID", value: adapter_incoming_request_params.dig("correlationId")),
        AdditionalDatum.new(format: "text", label: "Alert ID", value: adapter_incoming_request_params.dig("alertId")),
        AdditionalDatum.new(format: "text", label: "Entity ID", value: adapter_incoming_request_params.dig("entityId")),
        AdditionalDatum.new(format: "text", label: "Entity Name", value: adapter_incoming_request_params.dig("entityName")),
        AdditionalDatum.new(format: "text", label: "Entity Type", value: adapter_incoming_request_params.dig("entityType")),
        AdditionalDatum.new(format: "text", label: "Entity ID", value: adapter_incoming_request_params.dig("entityId")),
        AdditionalDatum.new(format: "text", label: "Company Name", value: adapter_incoming_request_params.dig("companyName")),
        AdditionalDatum.new(format: "datetime", label: "Date", value: adapter_incoming_request_params.dig("date"))
      ]
    end
  end
end
