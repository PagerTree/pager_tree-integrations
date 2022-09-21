module PagerTree::Integrations
  class Jotform::V3 < Integration
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
      adapter_incoming_request_params.dig("submissionID")
    end

    def adapter_action
      :create
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [],
        additional_data: _additional_datums
      )
    end

    private

    def _title
      [adapter_incoming_request_params.dig("formTitle"), adapter_incoming_request_params.dig("submissionID")].join(" ")
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Submission URL", value: "https://www.jotform.com/submission/#{adapter_incoming_request_params.dig("submissionID")}")
      ]
    end
  end
end
