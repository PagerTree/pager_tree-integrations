module PagerTree::Integrations
  class StatusGator::V3 < Integration
    OPTIONS = [
      {key: :create_on_warn, type: :boolean, default: true},
      {key: :create_on_maintenance, type: :boolean, default: true}
    ]
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
      adapter_incoming_request_params.dig("monitor", "id")
    end

    def adapter_action
      state = adapter_incoming_request_params.dig("status")
      if state == "down"
        :create
      elsif state == "up"
        :resolve
      elsif state == "maintenance" && option_create_on_maintenance == true
        :create
      elsif state == "warn" && option_create_on_warn == true
        :create
      else
        :other
      end
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        description: _description,
        thirdparty_id: adapter_thirdparty_id,
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

    def _additional_datums
      [
        AdditionalDatum.new(format: "text", label: "Monitor Name", value: adapter_incoming_request_params.dig("monitor", "display_name")),
        AdditionalDatum.new(format: "datetime", label: "Recorded At", value: adapter_incoming_request_params.dig("recorded_at"))
      ]
    end
  end
end
