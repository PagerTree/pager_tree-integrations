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
      {key: :template, type: :string, default: nil},
      {key: :send_linked, type: :boolean, default: false}
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
      self.option_send_linked ||= false
      self.option_template ||= ""
    end

    def adapter_supports_outgoing?
      true
    end

    def adapter_show_outgoing_webhook_delivery?
      true
    end

    def adapter_outgoing_interest?(event_name)
      try("option_#{event_name}") || false
    end

    def adapter_process_outgoing
      # TODO: Add the custom format option
      body = {
        data: adapter_outgoing_event.item,
        type: adapter_outgoing_event.event_name
      }

      # create the delivery, save it, and send it later
      outgoing_webhook_delivery = OutgoingWebhookDelivery.factory(
        resource: self,
        url: option_webhook_url,
        auth: {username: option_username, password: option_password},
        body: body
      )
      outgoing_webhook_delivery.save!
      outgoing_webhook_delivery.deliver_later
    end
  end
end
