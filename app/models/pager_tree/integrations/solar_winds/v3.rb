module PagerTree::Integrations
  class SolarWinds::V3 < Integration
    OPTIONS = [
      {key: :alert_acknowledged, type: :boolean, default: false},
      {key: :server_url, type: :string, default: nil},
      {key: :server_username, type: :string, default: nil},
      {key: :server_password, type: :string, default: nil},
      {key: :proxy_url, type: :string, default: nil}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    validates :option_alert_acknowledged, inclusion: {in: [true, false]}
    validates :option_server_username, presence: true, if: -> { option_alert_acknowledged == true }
    validates :option_server_password, presence: true, if: -> { option_alert_acknowledged == true }
    validates :option_server_url, presence: true, url: {no_local: true}, if: -> { option_alert_acknowledged == true }

    after_initialize do
      self.option_alert_acknowledged ||= false
      self.option_server_url ||= nil
      self.option_server_username ||= nil
      self.option_server_password ||= nil
      self.option_proxy_url ||= nil
    end

    def adapter_supports_incoming?
      true
    end

    def adapter_supports_outgoing?
      true
    end

    def adapter_show_outgoing_webhook_delivery?
      true
    end

    def adapter_incoming_can_defer?
      true
    end

    def adapter_outgoing_interest?(event_name)
      try("option_#{event_name}") || false
    end

    def adapter_process_outgoing
      try("adapter_process_outgoing_#{adapter_outgoing_event.event_name}")
    end

    def adapter_process_outgoing_alert_acknowledged
      return unless adapter_outgoing_event.alert.source == self

      ack_url = adapter_outgoing_event.alert&.source_log&.message&.dig("params", "AcknowledgeUrl")
      ack_uri = URI.parse(ack_url)
      server_uri = URI.parse(self.option_server_url)
      object_id = Rack::Utils.parse_query(ack_uri.query).dig("ObjID")
      url = "#{server_uri.origin}/SolarWinds/InformationService/v3/Json/Invoke/Orion.AlertActive/Acknowledge"
      body = {
        alertObjectIds: [object_id],
        notes: "Acknowledged by #{adapter_outgoing_event.alert&.alert_responders&.where(role: :incident_commander)&.includes(account_user: :user)&.first&.account_user&.user&.name}"
      }

      auth = {}

      if self.option_server_username.present? && self.option_server_password.present?
        auth = {
          username: self.option_server_username,
          password: self.option_server_password
        }
      end

      outgoing_webhook_delivery = OutgoingWebhookDelivery.factory(
        resource: self,
        url: url,
        body: body,
        auth: auth,
        proxy_url: option_proxy_url.presence
      )
      outgoing_webhook_delivery.save!
      outgoing_webhook_delivery.deliver_later

      outgoing_webhook_delivery
    rescue
    end

    def adapter_thirdparty_id
      adapter_incoming_request_params.dig("AlertID")
    end

    def adapter_action
      case adapter_incoming_request_params.dig("ActionType").to_s.downcase
      when "create"
        :create
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
      adapter_incoming_request_params.dig("AlertMessage")
    end

    def _description
      adapter_incoming_request_params.dig("AlertDescription")
    end

    def _urgency
      case adapter_incoming_request_params.dig(:severity).to_s.downcase
      when "notice", "informational"
        "low"
      when "warning"
        "medium"
      when "serious"
        "high"
      when "critical"
        "critical"
      end
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Alert Details URL", value: adapter_incoming_request_params.dig("AlertDetailsURL")),
        AdditionalDatum.new(format: "text", label: "Node", value: adapter_incoming_request_params.dig("NodeName"))
      ]
    end
  end
end
