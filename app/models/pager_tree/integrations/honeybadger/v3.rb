module PagerTree::Integrations
  class Honeybadger::V3 < Integration
    OPTIONS = [
      # only used if they set this up as a "webhook" from honeybadger, the native PT integration doesn't have the token option
      {key: :token, type: :string, default: nil}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    after_initialize do
      self.option_token ||= nil
    end

    def adapter_should_block_incoming?(request)
      self.option_token.present? && (request.headers["honeybadger-token"] != self.option_token)
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
      adapter_incoming_request_params.dig("fault", "url") || adapter_incoming_request_params.dig("outage", "details_url") || adapter_incoming_request_params.dig("check_in", "details_url")
    end

    def adapter_action
      event = adapter_incoming_request_params.dig("event").to_s.downcase
      case event
      when "occurred", "down", "check_in_missing"
        :create
      when "resolved", "up", "check_in_reporting"
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
      adapter_incoming_request_params.dig("message")
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Fault URL", value: adapter_incoming_request_params.dig("fault", "url")),
        AdditionalDatum.new(format: "text", label: "Environment", value: adapter_incoming_request_params.dig("fault", "environment")),
        AdditionalDatum.new(format: "link", label: "Outage URL", value: adapter_incoming_request_params.dig("outage", "details_url")),
        AdditionalDatum.new(format: "link", label: "Check In URL", value: adapter_incoming_request_params.dig("check_in", "details_url"))
      ]
    end

    def _tags
      (
        Array(adapter_incoming_request_params.dig("fault", "tags") || []) + Array(adapter_incoming_request_params.dig("fault", "environment"))
      ).map(&:strip).uniq.compact
    end
  end
end
