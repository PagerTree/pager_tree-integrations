module PagerTree::Integrations
  class Freshdesk::V3 < Integration
    FD_TICKET_STATUS = {
      open: 2,
      pending: 3,
      resolved: 4,
      closed: 5
    }

    FD_TICKET_PRIORITY = {
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
      _freshdesk_webhook.dig("ticket_id")
    end

    def adapter_action
      status = _freshdesk_webhook.dig("ticket_status")
      status_i = status&.to_i
      if status_i == FD_TICKET_STATUS[:open] || status == "Open" || status_i == FD_TICKET_STATUS[:pending] || status == "Pending"
        :create
      elsif status_i == FD_TICKET_STATUS[:resolved] || status == "Resolved" || status_i == FD_TICKET_STATUS[:closed] || status == "Closed"
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

    def _freshdesk_webhook
      adapter_incoming_request_params.dig("freshdesk_webhook")
    end

    def _title
      _freshdesk_webhook.dig("ticket_subject")
    end

    def _description
      _freshdesk_webhook.dig("ticket_description")
    end

    def _urgency
      priority = _freshdesk_webhook.dig("ticket_priority")
      priority_i = priority&.to_i

      if priority_i == FD_TICKET_PRIORITY[:low] || priority == "Low"
        :low
      elsif priority_i == FD_TICKET_PRIORITY[:medium] || priority == "Normal"
        :medium
      elsif priority_i == FD_TICKET_PRIORITY[:high] || priority == "High"
        :high
      elsif priority_i == FD_TICKET_PRIORITY[:urgent] || priority == "Urgent"
        :critical
      end
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Ticket URL", value: _freshdesk_webhook.dig("ticket_url")),
        AdditionalDatum.new(format: "datetime", label: "Due By", value: _freshdesk_webhook.dig("ticket_due_by_time")),
        AdditionalDatum.new(format: "text", label: "Source", value: _freshdesk_webhook.dig("ticket_source")),
        AdditionalDatum.new(format: "text", label: "Requester Name", value: _freshdesk_webhook.dig("ticket_requester_name")),
        AdditionalDatum.new(format: "text", label: "Requester Email", value: _freshdesk_webhook.dig("ticket_requester_email")),
        AdditionalDatum.new(format: "text", label: "Requester Phone", value: _freshdesk_webhook.dig("ticket_requester_phone")),
        AdditionalDatum.new(format: "text", label: "Company", value: _freshdesk_webhook.dig("ticket_company_name"))
      ]
    end
  end
end
