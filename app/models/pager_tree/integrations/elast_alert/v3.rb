module PagerTree::Integrations
  class ElastAlert::V3 < Integration
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
      adapter_incoming_request_params.dig("Id")
    end

    def adapter_action
      case _event_type
      when "create" then :create
      when "resolve" then :resolve
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

    # elastalert will raise an error for any 4xx or 5xx response and then retry for a default of 2 days
    # https://github.com/Yelp/elastalert/blob/master/elastalert/alerts.py#L1496
    # we don't want to get spammy with retries, so we'll just return a 200
    def adapter_response_rate_limit
      adapter_controller&.head(:ok)
    end

    def adapter_response_disabled
      adapter_controller&.head(:ok)
    end

    def adapter_response_inactive_subscription
      adapter_controller&.head(:ok)
    end

    def adapter_response_upgrade
      adapter_controller&.head(:ok)
    end

    def adapter_response_blocked
      adapter_controller&.head(:ok)
    end

    private

    # See https://github.com/Yelp/elastalert/pull/2001 for details
    def _event_type
      adapter_incoming_request_params.dig("event_type")
    end

    def _title
      adapter_incoming_request_params.dig("Title")
    end

    def _description
      adapter_incoming_request_params.dig("Description")
    end

    def _additional_datums
      []
    end
  end
end
