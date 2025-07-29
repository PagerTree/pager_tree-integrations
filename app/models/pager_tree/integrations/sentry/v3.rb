module PagerTree::Integrations
  class Sentry::V3 < Integration
    OPTIONS = [
      {key: :client_secret, type: :string, default: nil},
      {key: :authorization_token, type: :string, default: nil},
      {key: :authorization_token_expires_at, type: :string, default: nil},
      {key: :authorization_refresh_token, type: :string, default: nil},
      {key: :code, type: :string, default: nil}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    after_initialize do
    end

    after_create_commit do
      verify_installation if initialize_authorization_token!
    end

    def adapter_should_block_incoming?(request)
      should_block = false
      # https://docs.sentry.io/product/integrations/integration-platform/webhooks/#sentry-hook-signature
      client_secret = option_client_secret.presence || PagerTree::Integrations.integration_sentry_v3_client_secret
      if client_secret.present? && request.headers["sentry-hook-signature"].present?
        sentry_signature = request.headers["sentry-hook-signature"]
        data = request.body.read
        digest = OpenSSL::HMAC.hexdigest("SHA256", client_secret, data)
        should_block = sentry_signature != digest
      end

      should_block
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
      send("_#{hook_resource}_adapter_thirdparty_id")
    end

    def adapter_action
      return :other unless should_process?

      send("_#{hook_resource}_adapter_action")
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        description: _description,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: _dedup_keys,
        additional_data: _additional_datums
      )
    end

    def adapter_process_other
      _installation_process_other if installation?
    end

    def verify_installation
      if thirdparty_id.present?
        HTTParty.put("https://sentry.io/api/0/sentry-app-installations/#{thirdparty_id}/",
          headers: {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer #{option_authorization_token}"
          }, body: {
            status: "installed"
          }.to_json)

        return true
      end

      false
    rescue => e
      Rails.logger.error("Error sending Sentry App Installation Confirmation: #{e.message}")
      false
    end

    def initialize_authorization_token!
      if thirdparty_id.present? && option_code.present?
        response = HTTParty.post("https://sentry.io/api/0/sentry-app-installations/#{thirdparty_id}/authorizations/",
          headers: {
            "Content-Type" => "application/json"
          }, body: {
            grant_type: "authorization_code",
            code: option_code,
            client_id: PagerTree::Integrations.integration_sentry_v3_client_id,
            client_secret: PagerTree::Integrations.integration_sentry_v3_client_secret
          }.to_json)

        if response.code == 201
          json = JSON.parse(response.body)
          self.option_authorization_token = json.dig("token")
          self.option_authorization_refresh_token = json.dig("refreshToken")
          self.option_authorization_token_expires_at = json.dig("expiresAt")
          save!

          return true
        end
      end

      false
    rescue => e
      Rails.logger.error("Error initializing Sentry App Authorization Token: #{e.message}")
      false
    end

    def refresh_authorization_token!
      if thirdparty_id.present? && option_authorization_refresh_token.present?
        response = HTTParty.post("https://sentry.io/api/0/sentry-app-installations/#{thirdparty_id}/authorizations/",
          headers: {
            "Content-Type" => "application/json"
          }, body: {
            grant_type: "refresh_token",
            refresh_token: option_authorization_refresh_token,
            client_id: PagerTree::Integrations.integration_sentry_v3_client_id,
            client_secret: PagerTree::Integrations.integration_sentry_v3_client_secret
          }.to_json)

        if response.code == 201
          json = JSON.parse(response.body)
          self.option_authorization_token = json.dig("token")
          self.option_authorization_refresh_token = json.dig("refreshToken")
          self.option_authorization_token_expires_at = json.dig("expiresAt")
          save!

          return true
        end
      end

      false
    rescue => e
      Rails.logger.error("Error refreshing Sentry App Authorization Token: #{e.message}")
      false
    end

    private

    ############################
    # START INSTALLATION
    # https://docs.sentry.io/product/integrations/integration-platform/webhooks/installation/
    ############################

    def _installation_adapter_thirdparty_id
      incoming_json.dig("id")
    end

    def _installation_adapter_action
      :other
    end

    def _installation_title
      ""
    end

    def _installation_description
      ""
    end

    def _installation_additional_datums
      []
    end

    def _installation_dedup_keys
      []
    end

    def _installation_process_other
      action = incoming_json.dig("action")
      if action == "created"
        # intentionally left blank
      elsif action == "deleted"
        # clear the thirdparty id off this integration and save
        self.thirdparty_id = nil
        save!
      end
    end

    ############################
    # END Installation
    ############################

    ############################
    # START WEBHOOK
    # Undocumented webhook format (this is what you get when you just signup for a trial)
    ############################

    def _webhook_adapter_thirdparty_id
      incoming_json.dig("id")
    end

    def _webhook_adapter_action
      :create
    end

    def _webhook_title
      incoming_json.dig("event", "title")
    end

    def _webhook_description
      web_url = incoming_json.dig("url")
      "Please see <a href='#{web_url}' target='_blank'>Sentry issue</a> for full details." if web_url.present?
    end

    def _webhook_additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Web URL", value: incoming_json.dig("url")),
        AdditionalDatum.new(format: "text", label: "Project", value: incoming_json.dig("project_name"))
      ]
    end

    def _webhook_dedup_keys
      []
    end

    ############################
    # END WEBHOOK
    ############################

    ############################
    # START ISSUE
    # https://docs.sentry.io/product/integrations/integration-platform/webhooks/issues/
    ############################

    def _issue_adapter_thirdparty_id
      incoming_json.dig("data", "issue", "id")
    end

    def _issue_adapter_action
      case action
      when "created"
        :create
      when "resolved", "archived"
        :resolve
      when "assigned"
        :acknowledge
      else
        :other
      end
    end

    def _issue_title
      incoming_json.dig("data", "issue", "title")
    end

    def _issue_description
      web_url = incoming_json.dig("data", "issue", "web_url")
      "Please see <a href='#{web_url}' target='_blank'>Sentry issue</a> for full details." if web_url.present?
    end

    def _issue_additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Web URL", value: incoming_json.dig("data", "issue", "web_url"))
      ]
    end

    def _issue_dedup_keys
      []
    end

    ############################
    # END ISSUE
    ############################

    ############################
    # START EVENT ALERTS (ISSUE ALERTS)
    # https://docs.sentry.io/product/integrations/integration-platform/webhooks/issue-alerts/
    ############################

    def _event_alert_adapter_thirdparty_id
      incoming_json.dig("data", "event", "issue_id")
    end

    def _event_alert_adapter_action
      case action
      when "triggered"
        :create
      else
        :other
      end
    end

    def _event_alert_title
      incoming_json.dig("data", "event", "title")
    end

    def _event_alert_description
      web_url = incoming_json.dig("data", "event", "web_url")
      "Please see <a href='#{web_url}' target='_blank'>Sentry event</a> for full details." if web_url.present?
    end

    def _event_alert_additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Web URL", value: incoming_json.dig("data", "event", "web_url"))
      ]
    end

    def _event_alert_dedup_keys
      []
    end

    ############################
    # END EVENT ALERTS
    ############################

    ############################
    # START METRIC ALERTS
    # https://docs.sentry.io/product/integrations/integration-platform/webhooks/metric-alerts/
    ############################

    def _metric_alert_adapter_thirdparty_id
      incoming_json.dig("data", "metric_alert", "id")
    end

    def _metric_alert_adapter_action
      case action
      when "resolved"
        :resolve
      when "critical", "warning"
        :create
      else
        :other
      end
    end

    def _metric_alert_title
      incoming_json.dig("data", "description_title")
    end

    def _metric_alert_description
      incoming_json.dig("data", "description_text")
    end

    def _metric_alert_additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Web URL", value: incoming_json.dig("data", "metric_alert", "web_url"))
      ]
    end

    def _metric_alert_dedup_keys
      []
    end

    ############################
    # END METRIC ALERTS
    ############################

    ############################
    # START ERRORS
    # https://docs.sentry.io/product/integrations/integration-platform/webhooks/errors/
    ############################

    def _error_adapter_thirdparty_id
      incoming_json.dig("data", "error", "issue_id")
    end

    def _error_adapter_action
      case action
      when "created"
        :create
      else
        :other
      end
    end

    def _error_title
      incoming_json.dig("data", "error", "title")
    end

    def _error_description
      web_url = incoming_json.dig("data", "error", "web_url")
      "Please see <a href='#{web_url}' target='_blank'>Sentry event</a> for full details." if web_url.present?
    end

    def _error_additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Web URL", value: incoming_json.dig("data", "error", "web_url"))
      ]
    end

    def _error_dedup_keys
      []
    end

    ############################
    # END ERRORS
    ############################

    ############################
    # START COMMON
    ############################

    def _title
      send("_#{hook_resource}_title")
    end

    def _description
      send("_#{hook_resource}_description")
    end

    def _additional_datums
      send("_#{hook_resource}_additional_datums")
    end

    def _dedup_keys
      send("_#{hook_resource}_dedup_keys")
    end

    ############################
    # END COMMON
    ############################

    ############################
    # START DATA ACCESS
    ############################
    def incoming_headers
      adapter_incoming_deferred_request.headers
    end

    def incoming_body
      adapter_incoming_deferred_request.body
    end

    def incoming_json
      @_json ||= JSON.parse(incoming_body)
    end

    def hook_resource
      incoming_headers["HTTP_SENTRY_HOOK_RESOURCE"] || "webhook"
    end

    def issue?
      hook_resource == "issue"
    end

    def event_alert?
      hook_resource == "event_alert"
    end

    def metric_alert?
      hook_resource == "metric_alert"
    end

    def error?
      hook_resource == "error"
    end

    def installation?
      hook_resource == "installation"
    end

    def webhook?
      incoming_headers["HTTP_SENTRY_HOOK_RESOURCE"].blank? && (hook_resource == "webhook")
    end

    def should_process?
      issue? || event_alert? || metric_alert? || error? || installation? || webhook?
    end

    def action
      incoming_json.dig("action")
    end

    ############################
    # END DATA ACCESS
    ############################
  end
end
