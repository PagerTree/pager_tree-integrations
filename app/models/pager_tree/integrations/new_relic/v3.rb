module PagerTree::Integrations
  class NewRelic::V3 < Integration
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
      adapter_incoming_request_params.dig("incident_id")
    end

    def adapter_action
      event_type = adapter_incoming_request_params.dig("event_type")
      current_state = adapter_incoming_request_params.dig("current_state")

      if event_type == "INCIDENT_OPEN" || (event_type == "INCIDENT" && current_state == "open")
        :create
      elsif event_type == "INCIDENT_RESOLVED" || (event_type == "INCIDENT" && current_state == "closed")
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
        dedup_keys: [],
        additional_data: _additional_datums
      )
    end

    private

    def _title
      adapter_incoming_request_params.dig("condition_name")
    end

    def _description
      adapter_incoming_request_params.dig("details")
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "text", label: "Account Name", value: adapter_incoming_request_params.dig("account_name")),
        AdditionalDatum.new(format: "text", label: "Incident URL", value: adapter_incoming_request_params.dig("incident_url"))
      ]
    end
  end
end
