module PagerTree::Integrations
  class Zendesk::V3 < Integration
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
      case adapter_incoming_request_params.dig("event_type")
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
        dedup_keys: [],
        additional_data: _additional_datums
      )
    end

    private

    def _title
      adapter_incoming_request_params.dig("title")
    end

    def _description
      # this comes in as text format, so wrap it in a pre tag so it shows nicely in the web app
      "<pre>#{adapter_incoming_request_params.dig("description")}</pre>"
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Zendesk Link", value: adapter_incoming_request_params.dig("link")),
        AdditionalDatum.new(format: "text", label: "Priority", value: adapter_incoming_request_params.dig("priority")),
        AdditionalDatum.new(format: "text", label: "Ticket Type", value: adapter_incoming_request_params.dig("ticket_type")),
        AdditionalDatum.new(format: "text", label: "Via", value: adapter_incoming_request_params.dig("via")),
        AdditionalDatum.new(format: "text", label: "Assignee Name", value: adapter_incoming_request_params.dig("assignee_name"))
      ]
    end

    def _urgency
      case adapter_incoming_request_params.dig("priority").to_s.downcase
      when "urgent"
        "critical"
      when "high"
        "high"
      when "normal"
        "medium"
      when "low"
        "low"
      end
    end
  end
end
