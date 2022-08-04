module PagerTree::Integrations
  class StatusCake::V3 < Integration
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
      adapter_incoming_request_params.dig("URL")
    end

    def adapter_action
      case adapter_incoming_request_params.dig("Status").to_s.downcase
      when "down"
        :create
      when "up"
        :resolve
      else
        :other
      end
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [adapter_thirdparty_id],
        additional_data: _additional_datums,
        tags: _tags
      )
    end

    private

    def _title
      "#{adapter_incoming_request_params.dig("Name")} is down"
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "URL", value: adapter_incoming_request_params.dig("URL")),
        AdditionalDatum.new(format: "text", label: "Status Code", value: adapter_incoming_request_params.dig("StatusCode")),
        AdditionalDatum.new(format: "text", label: "IP", value: adapter_incoming_request_params.dig("IP")),
        AdditionalDatum.new(format: "text", label: "Check Rate", value: adapter_incoming_request_params.dig("Check Rate"))
      ]
    end

    def _tags
      adapter_incoming_request_params.dig("Tags").to_s.split(",").map(&:strip).uniq
    end
  end
end
