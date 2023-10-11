require "test_helper"

module PagerTree::Integrations
  class Sentry::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:sentry_v3)

      @error_create_request = JSON.parse(File.read("test/fixtures/files/models/pager_tree/integrations/sentry/error.json"))
      @event_alert_create_request = JSON.parse(File.read("test/fixtures/files/models/pager_tree/integrations/sentry/event_alert.json"))
      @issue_create_request = JSON.parse(File.read("test/fixtures/files/models/pager_tree/integrations/sentry/issue.json"))
      @metric_alert_create_request = JSON.parse(File.read("test/fixtures/files/models/pager_tree/integrations/sentry/metric_alert.json"))
      @webhook_create_request = JSON.parse(File.read("test/fixtures/files/models/pager_tree/integrations/sentry/webhook.json"))
    end

    test "sanity" do
      assert @integration.adapter_supports_incoming?
      assert @integration.adapter_incoming_can_defer?
      assert_not @integration.adapter_supports_outgoing?
      assert @integration.adapter_show_alerts?
      assert @integration.adapter_show_logs?
      assert_not @integration.adapter_show_outgoing_webhook_delivery?
    end

    # ERRORS
    test "adapter_actions_error_create" do
      @error_create_request["action"] = "created"
      @integration.adapter_incoming_request_params = @error_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'error'}, body: @error_create_request.to_json)
      assert_equal :create, @integration.adapter_action
    end

    test "adapter_actions_error_other" do
      @error_create_request["action"] = "non-existent"
      @integration.adapter_incoming_request_params = @error_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'error'}, body: @error_create_request.to_json)
      assert_equal :other, @integration.adapter_action

    end

    # EVENT ALERTS (ISSUE ALERTS)
    test "adapter_actions_event_alert_create" do
      @event_alert_create_request["action"] = "triggered"
      @integration.adapter_incoming_request_params = @event_alert_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'event_alert'}, body: @event_alert_create_request.to_json)
      assert_equal :create, @integration.adapter_action
    end

    test "adapter_actions_event_alert_other" do
      @event_alert_create_request["action"] = "non-existent"
      @integration.adapter_incoming_request_params = @event_alert_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'event_alert'}, body: @event_alert_create_request.to_json)
      assert_equal :other, @integration.adapter_action
    end

    # ISSUES
    test "adapter_actions_issue_create" do
      @issue_create_request["action"] = "created"
      @integration.adapter_incoming_request_params = @issue_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'issue'}, body: @issue_create_request.to_json)
      assert_equal :create, @integration.adapter_action
    end

    test "adapter_actions_issue_acknowledge" do
      @issue_create_request["action"] = "assigned"
      @integration.adapter_incoming_request_params = @issue_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'issue'}, body: @issue_create_request.to_json)
      assert_equal :acknowledge, @integration.adapter_action
    end

    test "adapter_actions_issue_resolve" do
      @issue_create_request["action"] = "resolved"
      @integration.adapter_incoming_request_params = @issue_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'issue'}, body: @issue_create_request.to_json)
      assert_equal :resolve, @integration.adapter_action
    end

    test "adapter_actions_issue_archive" do
      @issue_create_request["action"] = "archived"
      @integration.adapter_incoming_request_params = @issue_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'issue'}, body: @issue_create_request.to_json)
      assert_equal :resolve, @integration.adapter_action
    end

    test "adapter_actions_issue_other" do
      @issue_create_request["action"] = "non-existent"
      @integration.adapter_incoming_request_params = @issue_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'issue'}, body: @issue_create_request.to_json)
      assert_equal :other, @integration.adapter_action
    end

    # METRIC ALERTS
    test "adapter_actions_metric_alert_create" do
      @metric_alert_create_request["action"] = "critical"
      @integration.adapter_incoming_request_params = @metric_alert_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'metric_alert'}, body: @metric_alert_create_request.to_json)
      assert_equal :create, @integration.adapter_action
    end

    test "adapter_actions_metric_alert_warning" do
      @metric_alert_create_request["action"] = "warning"
      @integration.adapter_incoming_request_params = @metric_alert_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'metric_alert'}, body: @metric_alert_create_request.to_json)
      assert_equal :create, @integration.adapter_action
    end

    test "adapter_actions_metric_alert_resolve" do
      @metric_alert_create_request["action"] = "resolved"
      @integration.adapter_incoming_request_params = @metric_alert_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'metric_alert'}, body: @metric_alert_create_request.to_json)
      assert_equal :resolve, @integration.adapter_action
    end

    test "adapter_actions_metric_alert_other" do
      @metric_alert_create_request["action"] = "non-existent"
      @integration.adapter_incoming_request_params = @metric_alert_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'metric_alert'}, body: @metric_alert_create_request.to_json)
      assert_equal :other, @integration.adapter_action
    end

    # WEBHOOKS
    test "adapter_actions_webhook_create" do
      @integration.adapter_incoming_request_params = @webhook_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {}, body: @webhook_create_request.to_json)
      assert_equal :create, @integration.adapter_action
    end

    test "adapter_actions_webhook_other" do
      @webhook_create_request["action"] = "non-existent"
      @integration.adapter_incoming_request_params = @webhook_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {}, body: @webhook_create_request.to_json)
      assert_equal :create, @integration.adapter_action
    end

    test "adapter_thirdparty_id_error" do
      @integration.adapter_incoming_request_params = @error_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'error'}, body: @error_create_request.to_json)
      assert_equal @error_create_request.dig("data", "error", "issue_id"), @integration.adapter_thirdparty_id
      assert_not_nil @integration.adapter_thirdparty_id
    end

    test "adapter_thirdparty_id_event_alert" do
      @integration.adapter_incoming_request_params = @event_alert_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'event_alert'}, body: @event_alert_create_request.to_json)
      assert_equal @event_alert_create_request.dig("data", "event", "issue_id"), @integration.adapter_thirdparty_id
      assert_not_nil @integration.adapter_thirdparty_id
    end

    test "adapter_thirdparty_id_issue" do
      @integration.adapter_incoming_request_params = @issue_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'issue'}, body: @issue_create_request.to_json)
      assert_equal @issue_create_request.dig("data", "issue", "id"), @integration.adapter_thirdparty_id
      assert_not_nil @integration.adapter_thirdparty_id
    end

    test "adapter_thirdparty_id_metric_alert" do
      @integration.adapter_incoming_request_params = @metric_alert_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'metric_alert'}, body: @metric_alert_create_request.to_json)
      assert_equal @metric_alert_create_request.dig("data", "metric_alert", "id"), @integration.adapter_thirdparty_id
      assert_not_nil @integration.adapter_thirdparty_id
    end

    test "adapter_thirdparty_id_webhook" do
      @integration.adapter_incoming_request_params = @webhook_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {}, body: @webhook_create_request.to_json)
      assert_equal @webhook_create_request.dig("id"), @integration.adapter_thirdparty_id
      assert_not_nil @integration.adapter_thirdparty_id
    end

    test "adapter_process_create_error" do
      @error_create_request["action"] = "created"
      @integration.adapter_incoming_request_params = @error_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'error'}, body: @error_create_request.to_json)

      true_alert = Alert.new(
        title: @error_create_request.dig("data", "error", "title"),
        description: "Please see <a href='#{@error_create_request.dig("data", "error", "web_url")}' target='_blank'>Sentry event</a> for full details.",
        thirdparty_id: @error_create_request.dig("data", "error", "issue_id"),
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Web URL", value: @error_create_request.dig("data", "error", "web_url")),
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    test "adapter_process_create_event_alert" do
      @event_alert_create_request["action"] = "triggered"
      @integration.adapter_incoming_request_params = @event_alert_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'event_alert'}, body: @event_alert_create_request.to_json)

      true_alert = Alert.new(
        title: @event_alert_create_request.dig("data", "issue_alert", "title"),
        description: "Please see <a href='#{@event_alert_create_request.dig("data", "event", "web_url")}' target='_blank'>Sentry event</a> for full details.",
        thirdparty_id: @event_alert_create_request.dig("data", "event", "issue_id"),
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Web URL", value: @event_alert_create_request.dig("data", "event", "web_url")),
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    test "adapter_process_create_issue" do
      @issue_create_request["action"] = "created"
      @integration.adapter_incoming_request_params = @issue_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'issue'}, body: @issue_create_request.to_json)

      true_alert = Alert.new(
        title: @issue_create_request.dig("data", "issue", "title"),
        description: nil, # there is no web_url for issue test data
        thirdparty_id: @issue_create_request.dig("data", "issue", "id"),
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Web URL", value: @issue_create_request.dig("data", "issue", "web_url")),
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    test "adapter_process_create_metric_alert" do
      @metric_alert_create_request["action"] = "critical"
      @integration.adapter_incoming_request_params = @metric_alert_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {'HTTP_SENTRY_HOOK_RESOURCE' => 'metric_alert'}, body: @metric_alert_create_request.to_json)

      true_alert = Alert.new(
        title: @metric_alert_create_request.dig("data", "description_title"),
        description: @metric_alert_create_request.dig("data", "description_text"),
        thirdparty_id: @metric_alert_create_request.dig("data", "metric_alert", "id"),
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Web URL", value: @metric_alert_create_request.dig("data", "metric_alert", "web_url")),
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    test "adapter_process_create_webhook" do
      @webhook_create_request["action"] = "critical"
      @integration.adapter_incoming_request_params = @webhook_create_request
      @integration.adapter_incoming_deferred_request = OpenStruct.new(headers: {}, body: @webhook_create_request.to_json)

      true_alert = Alert.new(
        title: @webhook_create_request.dig("event", "title"),
        description: "Please see <a href='#{@webhook_create_request.dig("url")}' target='_blank'>Sentry issue</a> for full details.",
        thirdparty_id: @webhook_create_request.dig("id"),
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Web URL", value: @webhook_create_request.dig("url")),
          AdditionalDatum.new(format: "text", label: "Project", value: @webhook_create_request.dig("project_name")),
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
