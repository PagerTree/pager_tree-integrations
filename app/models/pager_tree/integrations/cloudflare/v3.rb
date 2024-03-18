module PagerTree::Integrations
  class Cloudflare::V3 < Integration
    OPTIONS = [
      {key: :webhook_secret, type: :string, default: nil}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    after_initialize do
      self.option_webhook_secret ||= nil
    end

    def adapter_should_block_incoming?(request)
      self.option_webhook_secret.present? && (request.headers["cf-webhook-auth"] != self.option_webhook_secret)
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
      @adapter_thirdparty_id ||= SecureRandom.uuid
    end

    def adapter_action
      :create
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
      adapter_incoming_request_params.dig("text")&.truncate(70) || "CF Event #{adapter_incoming_request_params.dig("text")&.titleize}"
    end

    def _description
      ActionController::Base.helpers.simple_format(adapter_incoming_request_params.dig("text"))
    end

    def _additional_datums
      timestamp = begin
        Time.at(adapter_incoming_request_params.dig("ts")).utc.to_datetime
      rescue
        nil
      end

      datums = []
      datums << AdditionalDatum.new(format: "text", label: "Account Name", value: adapter_incoming_request_params.dig("data", "account_name"))
      datums << AdditionalDatum.new(format: "text", label: "Zone Name", value: adapter_incoming_request_params.dig("data", "zone_name"))
      datums << AdditionalDatum.new(format: "link", label: "Dashboard Link", value: adapter_incoming_request_params.dig("data", "dashboard_link"))
      datums << AdditionalDatum.new(format: "datetime", label: "Timestamp", value: timestamp)
      datums << AdditionalDatum.new(format: "text", label: "Alert Type", value: adapter_incoming_request_params.dig("alert_type"))
      datums << AdditionalDatum.new(format: "text", label: "Account ID", value: adapter_incoming_request_params.dig("account_id"))
      datums << AdditionalDatum.new(format: "text", label: "Policy ID", value: adapter_incoming_request_params.dig("policy_id"))

      datums.filter { |datum| datum.value.present? }
    end
  end
end
