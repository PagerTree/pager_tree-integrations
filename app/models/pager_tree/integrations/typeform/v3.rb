module PagerTree::Integrations
  class Typeform::V3 < Integration
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
      adapter_incoming_request_params.dig("form_response", "token")
    end

    def adapter_action
      :create
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: []
      )
    end

    private

    def _title
      [adapter_incoming_request_params.dig("form_response", "definition", "title"), adapter_incoming_request_params.dig("form_response", "submitted_at")].compact_blank.join(": ")
    end
  end
end
