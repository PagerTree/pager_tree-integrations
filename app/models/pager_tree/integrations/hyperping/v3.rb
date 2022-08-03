module PagerTree::Integrations
  class Hyperping::V3 < Integration
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
      adapter_incoming_request_params.dig("check", "url")
    end

    def adapter_action
      event = adapter_incoming_request_params.dig("event")
      case event
      when "check.down"
        :create
      when "check.up"
        :resolve
      else
        :other
      end
    end

    # TODO: Implement your transform
    def adapter_process_create
      Alert.new(
        title: _title,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [adapter_thirdparty_id],
        additional_data: _additional_datums
      )
    end

    private

    def _title
      adapter_incoming_request_params.dig("check", "url") + " is DOWN"
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "URL", value: adapter_incoming_request_params.dig("check", "url")),
        AdditionalDatum.new(format: "text", label: "Status Code", value: adapter_incoming_request_params.dig("check", "status")),
        AdditionalDatum.new(format: "datetime", label: "Down Since", value: Time.at(adapter_incoming_request_params.dig("check", "date") / 1000).utc.to_datetime)
      ]
    end
  end
end
