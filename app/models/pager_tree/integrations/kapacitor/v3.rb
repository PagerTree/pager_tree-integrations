module PagerTree::Integrations
  class Kapacitor::V3 < Integration
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
      adapter_incoming_request_params.dig("id")
    end

    def adapter_action
      adapter_incoming_request_params.dig("level") == "OK" ? :resolve : :create
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
      adapter_incoming_request_params.dig("message")
    end

    def _description
      adapter_incoming_request_params.dig("details")
    end

    def _urgency
      case adapter_incoming_request_params.dig("level")
      when "INFO"
        "low"
      when "WARN"
        "medium"
      when "CRITICAL"
        "critical"
      end
    end

    def _additional_datums
      []
    end
  end
end
