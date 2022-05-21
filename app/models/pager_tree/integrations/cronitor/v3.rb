module PagerTree::Integrations
  class Cronitor::V3 < Integration
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
      adapter_incoming_request_params.dig("id")
    end

    def adapter_action
      case _type
      when "Alert" then :create
      when "Recovery" then :resolve
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
        additional_data: _additional_datums
      )
    end

    private

    def _title
      adapter_incoming_request_params.dig("monitor")
    end

    def _description
      adapter_incoming_request_params.dig("description")
    end

    def _type
      adapter_incoming_request_params.dig("type")
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "text", label: "Rule Violated", value: adapter_incoming_request_params.dig("rule"))
      ]
    end
  end
end
