module PagerTree::Integrations
  class Uptime::V3 < Integration
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
      adapter_incoming_request_params.dig("data", "service", "id")
    end

    def adapter_action
      case adapter_incoming_request_params.dig("event")
      when "alert_raised"
        :create
      when "alert_cleared"
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
        additional_data: _additional_datums,
        tags: _tags
      )
    end

    private

    def _title
      adapter_incoming_request_params.dig("data", "service", "display_name")
    end

    def _description
      adapter_incoming_request_params.dig("data", "alert", "output")
    end

    def _tags
      Array(adapter_incoming_request_params.dig("data", "service", "tags")).compact_blank.uniq
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "text", label: "Service Name", value: adapter_incoming_request_params.dig("data", "service", "name")),
        AdditionalDatum.new(format: "text", label: "Service Address", value: adapter_incoming_request_params.dig("data", "service", "msp_address"))
      ]
    end
  end
end
