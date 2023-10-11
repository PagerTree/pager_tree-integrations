module PagerTree::Integrations
  class Sentry::V3 < Integration
    OPTIONS = [
      {key: :client_secret, type: :string, default: nil}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    after_initialize do
    end

    def adapter_should_block_incoming?(request)
      should_block = false
      # https://docs.sentry.io/product/integrations/integration-platform/webhooks/#sentry-hook-signature
      if option_client_secret.present? && request.headers["sentry-hook-signature"].present?
        sentry_signature = request.headers["sentry-hook-signature"]
        data = adapter_incoming_request_params.to_json
        digest = OpenSSL::HMAC.hexdigest("SHA256", option_client_secret, data)
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

    private

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
    # END ISSUE
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
      incoming_json.dig("data", "issue_alert", "title")
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

    def webhook?
      incoming_headers["HTTP_SENTRY_HOOK_RESOURCE"].blank? && (hook_resource == "webhook")
    end

    def should_process?
      issue? || event_alert? || metric_alert? || error? || webhook?
    end

    def action
      incoming_json.dig("action")
    end

    ############################
    # END DATA ACCESS
    ############################
  end
end
