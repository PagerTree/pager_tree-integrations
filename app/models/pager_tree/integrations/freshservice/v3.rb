module PagerTree::Integrations
  class Freshservice::V3 < Integration
    FS_TICKET_STATUS = {
      open: 2,
      pending: 3,
      resolved: 4,
      closed: 5
    }

    FS_TICKET_PRIORITY = {
      low: 1,
      medium: 2,
      high: 3,
      urgent: 4
    }

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
      _freshservice_webhook.dig("ticket_public_url")
    end

    def adapter_action
      status = _freshservice_webhook.dig("ticket_status")
      status_i = status&.to_i

      if status_i == FS_TICKET_STATUS[:open] || status == "Open" || status_i == FS_TICKET_STATUS[:pending] || status == "Pending"
        :create
      elsif status_i == FS_TICKET_STATUS[:resolved] || status == "Resolved" || status_i == FS_TICKET_STATUS[:closed] || status == "Closed"
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

    def _freshservice_webhook
      # this is not a mistake, the webhook says fresh**desk**, not fresh**service**
      adapter_incoming_request_params.dig("freshdesk_webhook")
    end

    def _title
      _freshservice_webhook.dig("ticket_subject")
    end

    def _description
      _freshservice_webhook.dig("ticket_description")
    end

    def _urgency
      priority = _freshservice_webhook.dig("ticket_priority")
      priority_i = priority&.to_i

      if priority_i == FS_TICKET_PRIORITY[:low] || priority == "Low"
        "low"
      elsif priority_i == FS_TICKET_PRIORITY[:medium] || priority == "Normal" || priority == "Medium"
        "medium"
      elsif priority_i == FS_TICKET_PRIORITY[:high] || priority == "High"
        "high"
      elsif priority_i == FS_TICKET_PRIORITY[:urgent] || priority == "Urgent"
        "critical"
      end
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "text", label: "Ticket ID", value: _freshservice_webhook.dig("ticket_id")),
        AdditionalDatum.new(format: "link", label: "Ticket URL", value: _freshservice_webhook.dig("ticket_url")),
        AdditionalDatum.new(format: "text", label: "Requester Email", value: _freshservice_webhook.dig("ticket_email")),
        AdditionalDatum.new(format: "text", label: "To Email", value: _freshservice_webhook.dig("ticket_to_email")),
        AdditionalDatum.new(format: "text", label: "CC Email", value: _freshservice_webhook.dig("ticket_cc_email"))
      ]
    end
  end
end
