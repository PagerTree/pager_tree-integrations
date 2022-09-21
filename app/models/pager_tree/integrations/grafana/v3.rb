module PagerTree::Integrations
  class Grafana::V3 < Integration
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
      adapter_incoming_request_params.dig("ruleId")
    end

    def adapter_action
      case _state
      when "alerting"
        :create
      when "ok"
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
      adapter_incoming_request_params.dig("ruleName")
    end

    def _description
      adapter_incoming_request_params.dig("message")
    end

    def _state
      adapter_incoming_request_params.dig("state")
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "URL", value: adapter_incoming_request_params.dig("ruleURL")),
        AdditionalDatum.new(format: "img", label: "Image", value: adapter_incoming_request_params.dig("imageUrl"))
      ]
    end
  end
end
