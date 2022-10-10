module PagerTree::Integrations
  class SolarWinds::V3 < Integration
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
      adapter_incoming_request_params.dig("AlertID")
    end

    def adapter_action
      case adapter_incoming_request_params.dig("ActionType").to_s.downcase
      when "create"
        :create
      when "resolve"
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
        dedup_keys: [],
        additional_data: _additional_datums
      )
    end

    private

    def _title
      adapter_incoming_request_params.dig("AlertMessage")
    end

    def _description
      adapter_incoming_request_params.dig("AlertDescription")
    end

    def _urgency
      case adapter_incoming_request_params.dig(:severity).to_s.downcase
      when "notice", "informational"
        "low"
      when "warning"
        "medium"
      when "serious"
        "high"
      when "critical"
        "critical"
      else
        nil
      end
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Alert Details URL", value: adapter_incoming_request_params.dig("AlertDetailsURL")),
        AdditionalDatum.new(format: "text", label: "Node", value: adapter_incoming_request_params.dig("NodeName"))
      ]
    end
  end
end
