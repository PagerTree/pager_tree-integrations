module PagerTree::Integrations
  class AppDynamics::V3 < Integration
    OPTIONS = []
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    def adapter_supports_incoming?
      true
    end

    def adapter_action
      if _is_create?
        :create
      elsif _is_resolve?
        :resolve
      else
        :other
      end
    end

    def adapter_thirdparty_id
      _thirdparty_id
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        description: _description,
        thirdparty_id: _thirdparty_id,
        dedup_keys: [],
        additional_data: _additional_datums
      )
    end

    private

    def _thirdparty_id
      adapter_incoming_request_params.dig("details", "event_id")
    end

    def _state
      adapter_incoming_request_params.dig("event_type")
    end

    def _is_create?
      _state == "trigger"
    end

    def _is_resolve?
      _state == "resolve"
    end

    def _title
      adapter_incoming_request_params.dig("incident_key")
    end

    def _description
      [
        adapter_incoming_request_params.dig("description"),
        adapter_incoming_request_params.dig("details", "summary")
      ].join("\n\n")
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "text", label: "Event Name", value: adapter_incoming_request_params.dig("details", "event_name")),
        AdditionalDatum.new(format: "datetime", label: "Event Time", value: adapter_incoming_request_params.dig("details", "event_time")),
        AdditionalDatum.new(format: "text", label: "Application Name", value: adapter_incoming_request_params.dig("details", "application_name")),
        AdditionalDatum.new(format: "text", label: "Node Name", value: adapter_incoming_request_params.dig("details", "node_name")),
        AdditionalDatum.new(format: "img", label: adapter_incoming_request_params.dig("contexts", 0, "alt"), value: adapter_incoming_request_params.dig("contexts", 0, "src")),
        AdditionalDatum.new(format: "link", label: adapter_incoming_request_params.dig("contexts", 1, "text"), value: adapter_incoming_request_params.dig("contexts", 1, "href"))
      ]
    end
  end
end
