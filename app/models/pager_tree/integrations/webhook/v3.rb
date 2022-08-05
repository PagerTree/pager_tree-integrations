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
      adapter_incoming_request_params.dig("Id") || adapter_incoming_request_params.dig("id")
    end

    def adapter_action
      case adapter_incoming_request_params.dig("event_type").to_s.downcase.strip
      when "create"
        :create
        # when "acknowledge"
        # :acknowledge
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
        dedup_keys: [adapter_thirdparty_id],
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
      adapter_incoming_request_params.dig("Title") || adapter_incoming_request_params.dig("title")
    end

    def _description
      adapter_incoming_request_params.dig("Description") || adapter_incoming_request_params.dig("description")
    end

    def _tags
      tags = adapter_incoming_request_params.dig("Tags") || adapter_incoming_request_params.dig("tags")
      Array(tags).compact_blank.map(&:to_s).uniq
    end

    def _urgency
      urgency = adapter_incoming_request_params.dig("Urgency") || adapter_incoming_request_params.dig("urgency")
      urgency&.to_s&.downcase&.strip
    end

    def _incident
      !!adapter_incoming_request_params.dig("Meta", "incident")
    end

    def _incident_message
      adapter_incoming_request_params.dig("Meta", "incident_message")
    end

    def _incident_severity
      adapter_incoming_request_params.dig("Meta", "incident_severity")&.to_s&.upcase&.strip
    end

    def _meta
      meta = adapter_incoming_request_params.dig("Meta")
      meta.is_a?(Hash) ? meta.except("incident", "incident_message", "incident_severity") : {}
    end

    def _additional_datums
      if self.option_capture_additional_data == true
        adapter_incoming_request_params.except(
          "Id", "Title", "Description", "Urgency", "Tags", "Meta", "id", "title", "description", "urgency", "tags", "meta", "event_type", "pagertree_integration_id"
        ).map do |key, value|
          AdditionalDatum.new(format: "text", label: key, value: value.to_s)
        end
      else
        []
      end
    end
  end
end
