module PagerTree::Integrations
  class Datadog::V3 < Integration
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
      adapter_incoming_request_params.dig("ALERT_ID")
    end

    def adapter_action
      case _transition
      when "Triggered" then :create
      when "Recovered" then :resolve
      else
        :other
      end
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        description: _description,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [adapter_incoming_request_params.dig("AGGREG_KEY")].compact,
        additional_data: _additional_datums,
        tags: _tags
      )
    end

    private

    def _title
      adapter_incoming_request_params.dig("ALERT_TITLE")
    end

    def _description
      adapter_incoming_request_params.dig("ALERT_STATUS")
    end

    def _tags
      (adapter_incoming_request_params.dig("TAGS") || "").split(",").map(&:strip).uniq.compact
    end

    def _transition
      adapter_incoming_request_params.dig("ALERT_TRANSITION")
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Link", value: adapter_incoming_request_params.dig("LINK")),
        AdditionalDatum.new(format: "text", label: "Priority", value: adapter_incoming_request_params.dig("PRIORITY")),
        AdditionalDatum.new(format: "text", label: "Event Type", value: adapter_incoming_request_params.dig("EVENT_TYPE")),
        AdditionalDatum.new(format: "text", label: "Event Title", value: adapter_incoming_request_params.dig("EVENT_TITLE"))
      ]
    end
  end
end
