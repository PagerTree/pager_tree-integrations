module PagerTree::Integrations
  class DeadMansSnitch::V3 < Integration
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
      adapter_incoming_request_params.dig("data", "snitch", "token")
    end

    def adapter_action
      if _type == "snitch.missing" && _current_status == "missing" && _previous_status == "healthy"
        :create
      elsif _type == "snitch.reporting" && _current_status == "healthy" && _previous_status == "missing"
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

    def _type
      adapter_incoming_request_params.dig("type")
    end

    def _current_status
      adapter_incoming_request_params.dig("data", "snitch", "status")
    end

    def _previous_status
      adapter_incoming_request_params.dig("data", "snitch", "previous_status")
    end

    def _title
      adapter_incoming_request_params.dig("data", "snitch", "name")
    end

    def _description
      adapter_incoming_request_params.dig("data", "snitch", "notes")
    end

    def _tags
      adapter_incoming_request_params.dig("data", "snitch", "tags")
    end

    def _additional_datums
      []
    end
  end
end
