module PagerTree::Integrations
  class Webhook::V3 < Integration
    OPTIONS = [
      {key: :token, type: :string, default: nil},
      {key: :capture_additional_data, type: :boolean, default: false}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    after_initialize do
      self.option_token ||= nil
      self.option_capture_additional_data ||= false
    end

    def adapter_should_block_incoming?(request)
      self.option_token.present? && (request.headers["pagertree-token"] != self.option_token)
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
      _adapter_incoming_request_params.dig("id")
    end

    def adapter_action
      case _adapter_incoming_request_params.dig("event_type").to_s.downcase.strip
      when "create"
        :create
      when "acknowledge"
        :acknowledge
      when "resolve"
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
        dedup_keys: _dedup_keys,
        incident: _incident,
        incident_severity: _incident_severity,
        incident_message: _incident_message,
        tags: _tags,
        meta: _meta,
        additional_data: _additional_datums
      )
    end

    private

    def _title
      _adapter_incoming_request_params.dig("title")
    end

    def _description
      _adapter_incoming_request_params.dig("description")
    end

    def _tags
      tags = _adapter_incoming_request_params.dig("tags")
      Array(tags).compact_blank.map(&:to_s).uniq
    end

    def _urgency
      text = _adapter_incoming_request_params.dig("urgency")
      matches = /(?<urgency>low|medium|high|critical)/.match(text&.to_s&.downcase&.strip)
      matches ? matches[:urgency].to_s : nil
    end

    def _incident
      !!_adapter_incoming_request_params.dig("meta", "incident")
    end

    def _incident_message
      _adapter_incoming_request_params.dig("meta", "incident_message")
    end

    def _incident_severity
      _adapter_incoming_request_params.dig("meta", "incident_severity")&.to_s&.upcase&.strip
    end

    def _meta
      meta = _adapter_incoming_request_params.dig("meta")
      meta.is_a?(Hash) ? meta.except("incident", "incident_message", "incident_severity") : {}
    end

    def _additional_datums
      if self.option_capture_additional_data == true
        _adapter_incoming_request_params.except(
          "id", "title", "description", "urgency", "tags", "meta", "event_type", "pagertree_integration_id", "dedup_keys"
        ).map do |key, value|
          AdditionalDatum.new(format: "text", label: key, value: value.to_s)
        end
      else
        []
      end
    end

    def _dedup_keys
      Array(_adapter_incoming_request_params.dig("dedup_keys")).map(&:to_s).compact_blank.uniq
    end

    def _adapter_incoming_request_params
      adapter_incoming_request_params.transform_keys(&:downcase)
    end
  end
end
