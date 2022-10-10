module PagerTree::Integrations
  class Mattermost::OutgoingWebhook::V3 < Integration
    OPTIONS = [
      {key: :token, type: :string, default: nil}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    after_initialize do
      self.option_token ||= nil
    end

    def adapter_should_block_incoming?(request)
      self.option_token.present? && (request.params["token"] != self.option_token)
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
      "#{adapter_incoming_request_params.dig("channel_id")}.#{adapter_incoming_request_params.dig("timestamp")}"
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
      text = adapter_incoming_request_params.dig("text").to_s
      match = text.match(/low|medium|high|critical/i).try("[]", 0)
      match&.downcase!

      case match
      when "low"
        "low"
      when "medium"
        "medium"
      when "high"
        "high"
      when "critical"
        "critical"
      else
        nil
      end
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "text", label: "Trigger", value: adapter_incoming_request_params.dig("trigger_word")),
        AdditionalDatum.new(format: "text", label: "Channel", value: adapter_incoming_request_params.dig("channel_name")),
        AdditionalDatum.new(format: "text", label: "User", value: adapter_incoming_request_params.dig("user_name"))
      ]
    end
  end
end
