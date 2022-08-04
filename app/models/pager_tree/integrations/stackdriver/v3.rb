module PagerTree::Integrations
  class Stackdriver::V3 < Integration
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
      adapter_incoming_request_params.dig("incident", "incident_id")
    end

    def adapter_action
      case adapter_incoming_request_params.dig("incident", "state")
      when "open"
        :create
      when "closed"
        :resolve
      else
        :other
      end
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [adapter_thirdparty_id],
        additional_data: _additional_datums
      )
    end

    private

    def _title
      adapter_incoming_request_params.dig("incident", "summary")
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Incident URL", value: adapter_incoming_request_params.dig("incident", "url")),
        AdditionalDatum.new(format: "text", label: "Policy Name", value: adapter_incoming_request_params.dig("incident", "policy_name")),
        AdditionalDatum.new(format: "text", label: "Condition Name", value: adapter_incoming_request_params.dig("incident", "condition_name")),
        AdditionalDatum.new(format: "text", label: "Resource Name", value: adapter_incoming_request_params.dig("incident", "resource_name"))
      ]
    end
  end
end
