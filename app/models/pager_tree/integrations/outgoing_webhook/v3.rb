module PagerTree::Integrations
  class OutgoingWebhook::V3 < Integration
    OPTIONS = [
      {key: :webhook_url, type: :string, default: nil},
      {key: :username, type: :string, default: nil},
      {key: :password, type: :string, default: nil},
      {key: :alert_created, type: :boolean, default: false},
      {key: :alert_open, type: :boolean, default: false},
      {key: :alert_acknowledged, type: :boolean, default: false},
      {key: :alert_rejected, type: :boolean, default: false},
      {key: :alert_timeout, type: :boolean, default: false},
      {key: :alert_resolved, type: :boolean, default: false},
      {key: :alert_dropped, type: :boolean, default: false},
      {key: :alert_handoff, type: :boolean, default: false},
      {key: :event_reminder_going_on_call, type: :boolean, default: false},
      {key: :event_reminder_going_off_call, type: :boolean, default: false},
      {key: :template, type: :string, default: nil},
      {key: :send_linked, type: :boolean, default: false},
      {key: :outgoing_rules, type: :string, default: nil}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    validates :option_webhook_url, presence: true, url: {no_local: true}
    validates :option_alert_created, inclusion: {in: [true, false]}
    validates :option_alert_open, inclusion: {in: [true, false]}
    validates :option_alert_acknowledged, inclusion: {in: [true, false]}
    validates :option_alert_rejected, inclusion: {in: [true, false]}
    validates :option_alert_timeout, inclusion: {in: [true, false]}
    validates :option_alert_resolved, inclusion: {in: [true, false]}
    validates :option_alert_dropped, inclusion: {in: [true, false]}
    validates :option_alert_handoff, inclusion: {in: [true, false]}
    validates :option_event_reminder_going_on_call, inclusion: {in: [true, false]}
    validates :option_event_reminder_going_off_call, inclusion: {in: [true, false]}
    validates :option_send_linked, inclusion: {in: [true, false]}

    after_initialize do
      self.option_alert_created ||= false
      self.option_alert_open ||= false
      self.option_alert_acknowledged ||= false
      self.option_alert_rejected ||= false
      self.option_alert_timeout ||= false
      self.option_alert_resolved ||= false
      self.option_alert_dropped ||= false
      self.option_alert_handoff ||= false
      self.option_event_reminder_going_on_call ||= false
      self.option_event_reminder_going_off_call ||= false
      self.option_send_linked ||= false
      self.option_template ||= ""
      self.option_outgoing_rules ||= ""
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
      body = nil
      event_type = _map_event_name(adapter_outgoing_event.event_name)
      handlebars_data = {
        alert: adapter_outgoing_event.alert&.try(:v3_format) || adapter_outgoing_event&.alert,
        event: {
          type: event_type
        }
      }.compact

      # Do the custom templating portion for outgoing hooks
      if self.option_template.present?
        begin
          body = JSON.parse(handlebars(self.option_template, handlebars_data))
        rescue JSON::ParserError => e
          logs.create(message: "Error parsing JSON, abort custom format for option template. Error: #{e.message}")
        rescue => e
          Rails.logger.error "Error while processing option_template for #{id}: #{e.message}"
        end
      end

      if !body.present?
        body = {}
        body[:type] = event_type
        body[:data] = case event_type
        when "event_reminder.going_on_call", "event_reminder.going_off_call"
          {
            id: adapter_outgoing_event.event_reminder.id,
            prefix_id: adapter_outgoing_event.event_reminder.prefix_id,
            event: {
              id: adapter_outgoing_event.event_reminder.event.id,
              prefix_id: adapter_outgoing_event.event_reminder.event.prefix_id,
              start_time: adapter_outgoing_event.event_reminder.next_start.in_time_zone(adapter_outgoing_event.event_reminder.event.time_zone),
              end_time: adapter_outgoing_event.event_reminder.next_end.in_time_zone(adapter_outgoing_event.event_reminder.event.time_zone),
              time_zone: adapter_outgoing_event.event_reminder.event.time_zone,
              iana_time_zone: adapter_outgoing_event.event_reminder.event.iana_time_zone,
              layer: adapter_outgoing_event.event_reminder.event.layer,
              teams: adapter_outgoing_event.event_reminder.event.teams.map { |x| {id: x.id, tiny_id: x.tiny_id, prefix_id: x.prefix_id, name: x.name} },
              account_user: {
                id: adapter_outgoing_event.event_reminder.account_user.id,
                prefix_id: adapter_outgoing_event.event_reminder.account_user.prefix_id,
                user: {
                  id: adapter_outgoing_event.event_reminder.account_user.user.id,
                  prefix_id: adapter_outgoing_event.event_reminder.account_user.user.prefix_id,
                  name: adapter_outgoing_event.event_reminder.account_user.user.name,
                  email: adapter_outgoing_event.event_reminder.account_user.user.email
                }
              }

            }
          }
        else
          adapter_outgoing_event.alert&.try(:v3_format) || adapter_outgoing_event&.alert
        end
      end

      url = adapter_outgoing_event.outgoing_rules_data.dig("webhook_url") || option_webhook_url
      body.merge!(adapter_outgoing_event.outgoing_rules_data.except("webhook_url"))

      outgoing_webhook_delivery = OutgoingWebhookDelivery.factory(
        resource: self,
        url: url,
        auth: {username: option_username, password: option_password},
        body: body
      )
      outgoing_webhook_delivery.save!
      outgoing_webhook_delivery.deliver_later

      outgoing_webhook_delivery
    end

    def _map_event_name(event_name)
      case event_name
      when "event_reminder_going_on_call" then "event_reminder.going_on_call"
      when "event_reminder_going_off_call" then "event_reminder.going_off_call"
      else
        event_name.to_s.tr("_", ".")
      end
    end
  end
end
