module PagerTree::Integrations
  class Channel::Hangouts::V3 < Integration
    OPTIONS = [
      {key: :incoming_webhook_url, type: :string, default: nil},
      {key: :alert_open, type: :boolean, default: false},
      {key: :alert_assigned, type: :boolean, default: false},
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
      self.option_alert_assigned ||= false
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

    def adapter_supports_auto_aggregate?
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
      blocks_hash = {
        cards: [
          {
            header: {
              title: _title,
              subtitle: _alert.description&.try(:to_plain_text),
              imageUrl: _color,
              imageStyle: "AVATAR"
            },
            sections: [
              {
                widgets: [
                  {
                    textParagraph: {
                      text: _alert.description&.try(:to_plain_text)
                    }
                  },
                  {
                    keyValue: {
                      topLabel: "Status",
                      content: _alert.status.to_s.upcase
                    }
                  },
                  {
                    keyValue: {
                      topLabel: "Urgency",
                      content: _alert.urgency.to_s.upcase
                    }
                  },
                  {
                    keyValue: {
                      topLabel: "Created",
                      content: _alert.created_at.utc
                    }
                  },
                  {
                    keyValue: {
                      topLabel: "Source",
                      content: _alert.source&.name
                    }
                  },
                  {
                    keyValue: {
                      topLabel: "Destinations",
                      content: _alert.alert_destinations&.map { |d| d.destination.name }&.join(", ")
                    }
                  },
                  {
                    keyValue: {
                      topLabel: "User",
                      content: _alert.alert_responders&.where(role: :incident_commander)&.includes(account_user: :user)&.first&.account_user&.name
                    }
                  }
                ]

              }, {
                widgets: [
                  {
                    buttons: [
                      {
                        textButton: {
                          text: "VIEW IN PAGERTREE",
                          onClick: {
                            openLink: {
                              url: Rails.application.routes.url_helpers.try(:alert_url, _alert, script_name: "/#{_alert.account_id}")
                            }
                          }
                        }
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }

      blocks_hash[:cards][0][:sections][0][:widgets].reject! { |x| x.dig(:keyValue, :content).blank? && x.dig(:textParagraph, :text).blank? }

      blocks_hash
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
  end
end
