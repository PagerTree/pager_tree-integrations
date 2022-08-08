module PagerTree::Integrations
  class Channel::Slack::V3 < Integration
    OPTIONS = [
      {key: :incoming_webhook_url, type: :string, default: nil},
      {key: :alert_open, type: :boolean, default: false},
      {key: :alert_acknowledged, type: :boolean, default: false},
      {key: :alert_resolved, type: :boolean, default: false},
      {key: :alert_dropped, type: :boolean, default: false},
      {key: :outgoing_rules, type: :string, default: nil}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    validates :option_incoming_webhook_url, presence: true, url: {no_local: true}

    after_initialize do
      self.option_incoming_webhook_url ||= nil
      self.option_alert_open ||= false
      self.option_alert_acknowledged ||= false
      self.option_alert_resolved ||= false
      self.option_alert_dropped ||= false
      self.option_outgoing_rules ||= ""
    end

    def adapter_supports_incoming?
      false
    end

    def adapter_supports_outgoing?
      true
    end

    def adapter_show_outgoing_webhook_delivery?
      true
    end

    def adapter_supports_title_template?
      false
    end

    def adapter_supports_description_template?
      false
    end

    def adapter_outgoing_interest?(event_name)
      try("option_#{event_name}") || false
    end

    def adapter_process_outgoing
      url = adapter_outgoing_event.outgoing_rules_data.dig("webhook_url") || self.option_incoming_webhook_url
      body = _blocks.merge(adapter_outgoing_event.outgoing_rules_data.except("webhook_url"))

      outgoing_webhook_delivery = OutgoingWebhookDelivery.factory(
        resource: self,
        url: url,
        body: body
      )
      outgoing_webhook_delivery.save!
      outgoing_webhook_delivery.deliver_later

      outgoing_webhook_delivery
    end

    private

    def _alert
      @_alert ||= adapter_outgoing_event.item
    end

    def _blocks
      @_blocks ||= {
        username: "PagerTree",
        icon_url: "https://pagertree.com/assets/img/logo/pagertree-icon-256-256.png",
        text: "",
        attachments: [
          {
            fallback: _title,
            color: _color,
            title: _title,
            title_link: Rails.application.routes.url_helpers.try(:alert_url, _alert, script_name: "/#{_alert.account_id}"),
            text: _alert.description&.try(:to_plain_text),
            fields: [
              {
                title: "Status",
                value: _alert.status,
                short: "true"
              },
              {
                title: "Urgency",
                value: _alert.urgency,
                short: "true"
              },
              {
                title: "Created",
                value: "<!date^#{_alert.created_at.utc.to_i}^{date_num} {time_secs}|#{_alert.created_at.utc.to_i}>",
                short: "true"
              },
              {
                title: "Source",
                value: _alert.source&.name,
                short: "true"
              },
              {
                title: "Destinations",
                value: _alert.alert_destinations&.map { |d| d.destination.name }&.join(", "),
                short: "false"
              }
            ]
          }
        ]
      }
    end

    def _title
      return @_title if @_title.present?

      @_title = if _alert.incident?
        "Incident ##{_alert.tiny_id} [#{_alert.incident_severity.upcase.dasherize}] #{_alert.incident_message} - #{_alert.title}"
      else
        "Alert ##{_alert.tiny_id} #{_alert.title}"
      end
    end

    def _color
      case _alert.status
      when "open", "dropped"
        "#ff5252"
      when "acknowledged"
        "#fb8c00"
      when "resolved"
        "#4caf50"
      else
        "#555555"
      end
    end
  end
end
