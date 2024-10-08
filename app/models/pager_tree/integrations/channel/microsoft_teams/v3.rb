module PagerTree::Integrations
  class Channel::MicrosoftTeams::V3 < Integration
    OPTIONS = [
      {key: :incoming_webhook_url, type: :string, default: nil},
      {key: :alert_open, type: :boolean, default: false},
      {key: :alert_acknowledged, type: :boolean, default: false},
      {key: :alert_resolved, type: :boolean, default: false},
      {key: :alert_dropped, type: :boolean, default: false},
      {key: :outgoing_rules, type: :string, default: nil},
      {key: :time_zone, type: :string, default: nil}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    validates :option_incoming_webhook_url, presence: true, url: {no_local: true}
    validate :validate_time_zone_exists

    after_initialize do
      self.option_incoming_webhook_url ||= nil
      self.option_alert_open ||= false
      self.option_alert_acknowledged ||= false
      self.option_alert_resolved ||= false
      self.option_alert_dropped ||= false
      self.option_outgoing_rules ||= ""
      self.option_time_zone ||= "UTC"
    end

    def converts_to
      "PagerTree::Integrations::Channel::MicrosoftTeams::V4"
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

    def adapter_supports_auto_aggregate?
      false
    end

    def adapter_supports_auto_resolve?
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
      @_alert ||= adapter_outgoing_event.alert
    end

    def _blocks
      {
        "@type": "MessageCard",
        "@context": "http://schema.org/extensions",
        themeColor: _color,
        summary: _title,
        sections: [{
          activityTitle: _title,
          activitySubtitle: _alert.description&.try(:to_plain_text),
          facts: [
            {
              name: "Status",
              value: _alert.status.upcase
            },
            {
              name: "Urgency",
              value: _alert.urgency.upcase
            },
            {
              name: "Created",
              value: _alert.created_at.in_time_zone(option_time_zone).iso8601
            },
            {
              name: "Source",
              value: _alert.source&.name
            },
            {
              name: "Destinations",
              value: _alert.alert_destinations&.map { |d| d.destination.name }&.join(", ")
            },
            {
              name: "User",
              value: _alert.alert_responders&.where(role: :incident_commander)&.includes(account_user: :user)&.first&.account_user&.name
            }
          ],
          markdown: true
        }],
        potentialAction: [
          {
            "@context": "http://schema.org",
            "@type": "ViewAction",
            name: "View in PagerTree",
            target: [
              Rails.application.routes.url_helpers.try(:alert_url, _alert, script_name: "/#{_alert.account_id}")
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

    def validate_time_zone_exists
      return if option_time_zone.present? && ActiveSupport::TimeZone[option_time_zone].present?
      errors.add(:option_time_zone, "does not exist")
    end
  end
end
