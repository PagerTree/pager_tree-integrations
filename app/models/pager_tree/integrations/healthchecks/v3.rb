module PagerTree::Integrations
  class Healthchecks::V3 < Integration
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
      adapter_incoming_request_params.dig("incident_key")
    end

    def adapter_action
      case adapter_incoming_request_params.dig("event_type")
      when "trigger"
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
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [adapter_thirdparty_id],
        additional_data: _additional_datums,
        tags: _tags
      )
    end

    private

    def _title
      adapter_incoming_request_params.dig("title")
    end

    def _description
      adapter_incoming_request_params.dig("description")
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Client URL", value: adapter_incoming_request_params.dig("client_url")),
        AdditionalDatum.new(format: "text", label: "Client", value: adapter_incoming_request_params.dig("client"))
      ]
    end

    def _tags
      (adapter_incoming_request_params.dig("tags") || "").split(" ").map(&:strip).uniq.compact
    end
  end
end
