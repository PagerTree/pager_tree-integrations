module PagerTree::Integrations
  class Pingdom::V3 < Integration
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
      adapter_incoming_request_params.dig("check_id")
    end

    def adapter_action
      previous_state = adapter_incoming_request_params.dig("previous_state")
      current_state = adapter_incoming_request_params.dig("current_state")

      if (previous_state == "UP" && current_state == "DOWN") || (previous_state == "SUCCESS" && current_state == "FAILING")
        :create
      elsif (previous_state == "DOWN" && current_state == "UP") || (previous_state == "FAILING" && current_state == "SUCCESS")
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
        additional_data: _additional_datums,
        tags: _tags
      )
    end

    private

    def _title
      [adapter_incoming_request_params.dig("check_name"), adapter_incoming_request_params.dig("current_state")].join(" ")
    end

    def _description
      adapter_incoming_request_params.dig("description")
    end

    def _tags
      adapter_incoming_request_params.dig("tags") || []
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Full URL", value: adapter_incoming_request_params.dig("check_params", "full_url")),
        AdditionalDatum.new(format: "text", label: "Importance Level", value: adapter_incoming_request_params.dig("importance_level")),
        AdditionalDatum.new(format: "text", label: "Custom Message", value: adapter_incoming_request_params.dig("custom_message"))
      ]
    end
  end
end
