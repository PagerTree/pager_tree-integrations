module PagerTree::Integrations
  class Meta::Workplace::V3 < Integration
    OPTIONS = [
      {key: :incoming_enabled, type: :boolean, default: false},
      {key: :outgoing_enabled, type: :boolean, default: true},
      {key: :access_token, type: :string, default: nil},
      {key: :app_secret, type: :string, default: nil},
      {key: :group_id, type: :string, default: nil},
      {key: :outgoing_rules, type: :string, default: nil}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    validates :option_incoming_enabled, inclusion: {in: [true, false]}
    validates :option_outgoing_enabled, inclusion: {in: [true, false]}
    validates :option_access_token, presence: true
    validates :option_app_secret, presence: true
    validates :option_group_id, presence: true

    after_initialize do
      self.option_incoming_enabled = false if option_incoming_enabled.nil?
      self.option_outgoing_enabled = true if option_outgoing_enabled.nil?
      self.option_outgoing_rules ||= ""
    end

    def endpoint
      super + "/g"
    end

    def adapter_should_block_incoming?(request)
      should_block = false

      if option_app_secret.present? && request.headers["x-hub-signature-256"].present?
        signature = request.headers["x-hub-signature-256"].delete_prefix("sha256=")
        data = request.body.read
        digest = OpenSSL::HMAC.hexdigest("SHA256", option_app_secret, data)
        should_block = signature != digest
      end

      should_block
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
      false
    end

    def adapter_supports_title_template?
      false
    end

    def adapter_supports_description_template?
      false
    end

    def adapter_thirdparty_id
      [_entry&.dig("id"), _entry&.dig("time")].compact_blank.join("-")
    end

    def adapter_action
      if option_incoming_enabled && adapter_incoming_request_params.dig("object") == "page" && _entry_changes&.dig("field") == "mention"
        :create
      else
        :other
      end
    end

    def adapter_response_incoming
      if adapter_incoming_request_params["hub.mode"] == "subscribe"
        adapter_controller&.render(plain: adapter_incoming_request_params["hub.challenge"])
      else
        adapter_controller&.head(:ok)
      end
    end

    def adapter_process_create
      # send back an ok
      post_id = _entry_changes&.dig("value", "post_id")
      _post_comment(post_id, "Ok") if post_id.present?

      Alert.new(
        title: _title,
        thirdparty_id: adapter_thirdparty_id
      )
    end

    def adapter_process_other
    end

    def adapter_outgoing_interest?(event_name)
      option_outgoing_enabled && [
        "alert_created",
        "alert_acknowledged",
        "alert_rejected",
        "alert_resolved",
        "alert_dropped",
        "alert_handoff"
      ].include?(event_name)
    end

    def adapter_process_outgoing
      event_type = adapter_outgoing_event.event_name
      message = _generate_message(event_type)

      return unless message.present?

      if event_type == "alert_created"
        _post_message(option_group_id, message)
      else
        post_id = _alert.meta["meta_workplace_post_id"]

        if post_id.blank?
          outgoing_webhook_delivery_id = _alert.meta["meta_workplace_outgoing_webhook_delivery_id"]
          outgoing_webhook_delivery = OutgoingWebhookDelivery.find(outgoing_webhook_delivery_id)
          post_id = begin
            JSON.parse(outgoing_webhook_delivery.responses.first.dig("body"))["id"]
          rescue
            nil
          end

          if post_id.present?
            _alert.meta["meta_workplace_post_id"] = post_id
            _alert.save!
          end
        end

        _post_comment(post_id, message) if post_id.present?
      end
    end

    private

    # INCOMING
    def _entry
      @_entry ||= adapter_incoming_request_params&.dig("entry", 0)
    end

    def _entry_changes
      @_entry_changes ||= _entry&.dig("changes", 0)
    end

    def _title
      _entry_changes&.dig("value", "message")
    end

    def _additional_datums
      []
    end

    # OUTGOING
    def _alert
      @_alert ||= adapter_outgoing_event.alert
    end

    def _post_message(group_id, message)
      # This operation needs to happen immediately because we need to attach the post_id to the alert
      url = "https://graph.facebook.com/#{group_id}/feed?message=#{CGI.escape(message)}&formatting=MARKDOWN"
      outgoing_webhook_delivery = _send_outgoing(url)
      _alert.meta["meta_workplace_outgoing_webhook_delivery_id"] = outgoing_webhook_delivery.id
      _alert.save!

      outgoing_webhook_delivery
    end

    def _post_comment(post_id, message)
      url = "https://graph.facebook.com/#{post_id}/comments?message=#{CGI.escape(message)}"
      _send_outgoing(url)
    end

    def _send_outgoing(url)
      outgoing_webhook_delivery = OutgoingWebhookDelivery.factory(
        resource: self,
        url: url,
        options: {
          headers: {
            "Authorization" => "Bearer #{option_access_token}"
          }
        }
      )
      outgoing_webhook_delivery.save!
      outgoing_webhook_delivery.deliver_later

      outgoing_webhook_delivery
    end

    def _generate_message(event_name)
      case event_name
      when "alert_created"
        if _alert.incident?
          "[Incident ##{_alert.tiny_id}](#{Rails.application.routes.url_helpers.try(:alert_url, _alert, script_name: "/#{_alert.account_id}")}) [#{_alert.incident_severity.upcase.dasherize}] #{_alert.incident_message} - #{_alert.title}"
        else
          "[Alert ##{_alert.tiny_id}](#{Rails.application.routes.url_helpers.try(:alert_url, _alert, script_name: "/#{_alert.account_id}")}) #{_alert.title}"
        end
      when "alert_acknowledged"
        acknowledger = adapter_outgoing_event.account_user || adapter_outgoing_event.team
        acknowledger&.name&.present? ? "Acknowledged by #{acknowledger.name}" : "Acknowledged"
      when "alert_rejected"
        rejecter = adapter_outgoing_event.account_user
        rejecter&.name&.present? ? "Rejected by #{rejecter.name}" : "Rejected"
      when "alert_resolved"
        resolver = adapter_outgoing_event.account_user || adapter_outgoing_event.team
        resolver&.name&.present? ? "Resolved by #{resolver.name}" : "Resolved"
      when "alert_dropped"
        "Dropped"
      when "alert_handoff"
        handoff = adapter_outgoing_event.handoff
        "Handed off from #{handoff.source.name} to #{handoff.destination.name}"
      end
    end
  end
end
