module PagerTree::Integrations
  class Prometheus::V3 < Integration
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
      adapter_incoming_request_params.dig("groupKey")
    end

    def adapter_action
      case adapter_incoming_request_params.dig("status")
      when "firing"
        :create
      when "resolved"
        :resolve
      else
        :other
      end
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        description: _description,
        urgency: _urgency,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [adapter_thirdparty_id],
        additional_data: _additional_datums
      )
    end

    private

    def _title
      adapter_incoming_request_params.dig("commonLabels", "alertname") || ["Prometheus", adapter_incoming_request_params.dig("receiver"), "firing"].compact_blank.join(" ")
    end

    def _description
      adapter_incoming_request_params.dig("commonAnnotations", "summary")
    end

    def _urgency
      case adapter_incoming_request_params.dig("commonLabels", "severity")
      when "low"
        "low"
      when "medium"
        "medium"
      when "high"
        "high"
      when "critical"
        "critical"
      end
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Alert Manager URL", value: adapter_incoming_request_params.dig("externalURL")),
        AdditionalDatum.new(format: "text", label: "Receiver", value: adapter_incoming_request_params.dig("receiver"))
      ] + adapter_incoming_request_params.dig("commonLabels").map do |key, value|
        AdditionalDatum.new(format: "text", label: key, value: value.to_s)
      end
    end
  end
end
