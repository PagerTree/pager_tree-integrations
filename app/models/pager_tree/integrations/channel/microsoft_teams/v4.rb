module PagerTree::Integrations
  class Channel::MicrosoftTeams::V4 < Integration
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
        type: "message",
        attachments: [
          {
            contentType: "application/vnd.microsoft.card.adaptive",
            contentUrl: nil,
            content: {
              type: "AdaptiveCard",
              body: [
                {
                  type: "Container",
                  backgroundImage: _color,
                  items: [
                    {
                      type: "TextBlock",
                      size: "Large",
                      weight: "Bolder",
                      text: _title
                    },
                    {
                      type: "ColumnSet",
                      columns: [
                        {
                          type: "Column",
                          items: [
                            {
                              type: "TextBlock",
                              weight: "Bolder",
                              text: _title,
                              wrap: true
                            },
                            {
                              type: "TextBlock",
                              spacing: "None",
                              text: "Created #{_alert.created_at.in_time_zone(option_time_zone).iso8601}",
                              wrap: true
                            }
                          ],
                          width: "stretch"
                        }
                      ]
                    }
                  ]
                },
                {
                  type: "Container",
                  items: [
                    {
                      type: "FactSet",
                      facts: [
                        {
                          title: "Status:",
                          value: _alert.status&.upcase
                        }, {
                          title: "Urgency:",
                          value: _alert.urgency&.upcase
                        }, {
                          title: "Source:",
                          value: _alert.source&.name
                        }, {
                          title: "Destinations:",
                          value: _alert.alert_destinations&.map { |d| d.destination.name }&.join(", ")
                        }, {
                          title: "User:",
                          value: _alert.alert_responders&.where(role: :incident_commander)&.includes(account_user: :user)&.first&.account_user&.name
                        }
                      ],
                      spacing: "None"
                    }
                  ],
                  spacing: "Medium"
                },
                {
                  type: "Container",
                  items: [
                    {
                      type: "TextBlock",
                      text: _alert.description&.try(:to_plain_text),
                      wrap: true,
                      separator: true,
                      maxLines: 24
                    },
                    {
                      type: "FactSet",
                      facts: _alert.additional_data&.map { |ad| {title: ad["label"], value: Array(ad["value"]).join(", ")} } || [],
                      spacing: "Medium",
                      separator: true
                    }
                  ],
                  spacing: "Medium",
                  separator: true
                }
              ],
              actions: [
                {
                  type: "Action.OpenUrl",
                  title: "View",
                  url: Rails.application.routes.url_helpers.try(:alert_url, _alert, script_name: "/#{_alert.account_id}"),
                  style: "positive"
                }
              ],
              "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
              version: "1.2"
            }
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
        "https://pagertree.com/assets/img/icon/red-square.png"
      when "acknowledged"
        "https://pagertree.com/assets/img/icon/yellow-square.png"
      when "resolved"
        "https://pagertree.com/assets/img/icon/green-square.png"
      else
        "https://pagertree.com/assets/img/icon/grey-square.png"
      end
    end

    def validate_time_zone_exists
      return if option_time_zone.present? && ActiveSupport::TimeZone[option_time_zone].present?
      errors.add(:option_time_zone, "does not exist")
    end
  end
end
