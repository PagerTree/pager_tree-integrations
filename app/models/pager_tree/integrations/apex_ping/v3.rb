# https://apex.sh/docs/ping/webhooks/

module PagerTree::Integrations
  class ApexPing::V3 < Integration
    OPTIONS = []
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    def adapter_supports_incoming?
      true
    end

    def adapter_thirdparty_id
      _thirdparty_id
    end

    def adapter_action
      if _is_create?
        :create
      elsif _is_resolve?
        :resolve
      else
        :other
      end
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        thirdparty_id: _thirdparty_id,
        dedup_keys: [], 
        additional_data: _additional_datums
      )
    end

    private

    def _thirdparty_id
      adapter_incoming_request_params.dig("alert", "id")
    end

    def _state
      adapter_incoming_request_params.dig("state")
    end

    def _check_name
      adapter_incoming_request_params.dig("check", "name")
    end

    def _is_create?
      _state == "triggered"
    end

    def _is_resolve?
      _state == "resolved"
    end

    def _title
      "#{_check_name} #{_state}"
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "URL", value: "#{adapter_incoming_request_params.dig("check", "protocol")}://#{adapter_incoming_request_params.dig("check", "url")}"),
        AdditionalDatum.new(format: "text", label: "Method", value: adapter_incoming_request_params.dig("check", "method")),
        AdditionalDatum.new(format: "datetime", label: "Triggered At", value: adapter_incoming_request_params.dig("triggered_at"))
      ]
    end
  end
end
