module PagerTree::Integrations
  class Slack::Webhook::V3 < Integration
    OPTIONS = [
      {key: :token, type: :string, default: nil}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    after_initialize do
    end

    def adapter_should_block_incoming?(request)
      option_token.present? && (request.params["token"] != option_token)
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
      [adapter_incoming_request_params.dig("channel_id"), adapter_incoming_request_params.dig("timestamp")].join(".")
    end

    def adapter_action
      :create
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        urgency: _urgency,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [],
        additional_data: _additional_datums
      )
    end

    private

    def _title
      adapter_incoming_request_params.dig("text")
    end

    def _urgency
      text = adapter_incoming_request_params.dig("text")&.downcase
      matches = /(?<urgency>low|medium|high|critical)/.match(text)
      matches ? matches[:urgency].to_sym : urgency
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "text", label: "Trigger", value: adapter_incoming_request_params.dig("trigger_word")),
        AdditionalDatum.new(format: "text", label: "Channel", value: adapter_incoming_request_params.dig("channel")),
        AdditionalDatum.new(format: "text", label: "User", value: adapter_incoming_request_params.dig("user_name"))
      ]
    end
  end
end
