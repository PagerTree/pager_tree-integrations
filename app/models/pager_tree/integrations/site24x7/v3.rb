module PagerTree::Integrations
  class Site24x7::V3 < Integration
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
      adapter_incoming_request_params.dig("MONITOR_ID")
    end

    def adapter_action
      case adapter_incoming_request_params.dig("STATUS")
      when "DOWN"
        :create
      when "UP"
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
      "#{adapter_incoming_request_params.dig("MONITORNAME")} is DOWN"
    end

    def _description
      "#{adapter_incoming_request_params.dig("MONITORNAME")} is DOWN because #{adapter_incoming_request_params.dig("INCIDENT_REASON")}"
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Site 24x7 Dashboard URL", value: adapter_incoming_request_params.dig("MONITOR_DASHBOARD_LINK")),
        AdditionalDatum.new(format: "text", label: "Monitor Name", value: adapter_incoming_request_params.dig("MONITORNAME")),
        AdditionalDatum.new(format: "link", label: "Monitor URL", value: adapter_incoming_request_params.dig("MONITORURL")),
        AdditionalDatum.new(format: "text", label: "Group Name", value: adapter_incoming_request_params.dig("MONITOR_GROUPNAME")),
        AdditionalDatum.new(format: "text", label: "Reason", value: adapter_incoming_request_params.dig("INCIDENT_REASON")),
        AdditionalDatum.new(format: "text", label: "Failed Locations", value: adapter_incoming_request_params.dig("FAILED_LOCATIONS")),
        AdditionalDatum.new(format: "datetime", label: "Failed At", value: adapter_incoming_request_params.dig("INCIDENT_TIME_ISO"))
      ]
    end
  end
end
