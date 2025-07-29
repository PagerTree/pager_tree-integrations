module PagerTree::Integrations
  class Dynatrace::V3 < Integration
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
      adapter_incoming_request_params.dig("ProblemID")
    end

    def adapter_action
      state = adapter_incoming_request_params.dig("State")
      return :create if state == "OPEN"
      return :resolve if state == "RESOLVED"
      :other
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        description: _description,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [],
        additional_data: _additional_datums,
        tags: _tags
      )
    end

    private

    def _title
      adapter_incoming_request_params.dig("ProblemTitle")
    end

    def _description
      adapter_incoming_request_params.dig("ProblemDetailsHTML").presence ||
        adapter_incoming_request_params.dig("ProblemDetailsText").presence
    end

    def _tags
      (adapter_incoming_request_params.dig("Tags") || "").split(",").map(&:strip).uniq.compact
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "URL", value: adapter_incoming_request_params.dig("ProblemURL")),
        AdditionalDatum.new(format: "text", label: "Impacted Entity", value: adapter_incoming_request_params.dig("ImpactedEntity")),
        AdditionalDatum.new(format: "text", label: "Problem Impact", value: adapter_incoming_request_params.dig("ProblemImpact")),
        AdditionalDatum.new(format: "text", label: "Problem Severity", value: adapter_incoming_request_params.dig("ProblemSeverity"))
      ]
    end
  end
end
