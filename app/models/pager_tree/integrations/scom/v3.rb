module PagerTree::Integrations
  class Scom::V3 < Integration
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
      adapter_incoming_request_params.dig("alertId")
    end

    def adapter_action
      case adapter_incoming_request_params.dig("resolutionState")
      when "New" then :create
      when "Closed" then :resolve
      else
        :other
      end
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        description: _description,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [],
        additional_data: _additional_datums
      )
    end

    private

    def _title
      adapter_incoming_request_params.dig("alertName")
    end

    def _description
      adapter_incoming_request_params.dig("alertDescription")
    end

    def _additional_datums
      []
    end
  end
end
