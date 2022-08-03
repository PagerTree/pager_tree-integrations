require "test_helper"

module PagerTree::Integrations
  class NewRelic::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:new_relic_v3)

      @create_request = {
        account_id: "$ACCOUNT_ID",
        account_name: "$ACCOUNT_NAME",
        closed_violations_count_critical: "$CLOSED_VIOLATIONS_COUNT_CRITICAL",
        closed_violations_count_warning: "$CLOSED_VIOLATIONS_COUNT_WARNING",
        condition_family_id: "$CONDITION_FAMILY_ID",
        condition_id: "$CONDITION_ID",
        condition_name: "$CONDITION_NAME",
        current_state: "$EVENT_STATE",
        details: "$EVENT_DETAILS",
        duration: "$DURATION",
        event_type: "INCIDENT_OPEN",
        incident_acknowledge_url: "$INCIDENT_ACKNOWLEDGE_URL",
        incident_id: "$INCIDENT_ID",
        incident_url: "$INCIDENT_URL",
        open_violations_count_critical: "$OPEN_VIOLATIONS_COUNT_CRITICAL",
        open_violations_count_warning: "$OPEN_VIOLATIONS_COUNT_WARNING",
        owner: "$EVENT_OWNER",
        policy_name: "$POLICY_NAME",
        policy_url: "$POLICY_URL",
        runbook_url: "$RUNBOOK_URL",
        severity: "$SEVERITY",
        targets: "$TARGETS",
        timestamp: "$TIMESTAMP",
        timestamp_utc_string: "$TIMESTAMP_UTC_STRING",
        violation_callback_url: "$VIOLATION_CALLBACK_URL",
        violation_chart_url: "$VIOLATION_CHART_URL",
        team: "DevOps"
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:event_type] = "INCIDENT_RESOLVED"

      @other_request = @create_request.deep_dup
      @other_request[:event_type] = "baaad"
    end

    test "sanity" do
      assert @integration.adapter_supports_incoming?
      assert @integration.adapter_incoming_can_defer?
      assert_not @integration.adapter_supports_outgoing?
      assert @integration.adapter_show_alerts?
      assert @integration.adapter_show_logs?
      assert_not @integration.adapter_show_outgoing_webhook_delivery?
    end

    test "adapter_actions" do
      @integration.adapter_incoming_request_params = @create_request
      assert_equal :create, @integration.adapter_action

      @integration.adapter_incoming_request_params = @resolve_request
      assert_equal :resolve, @integration.adapter_action

      @integration.adapter_incoming_request_params = @other_request
      assert_equal :other, @integration.adapter_action
    end

    test "adapter_thirdparty_id" do
      @integration.adapter_incoming_request_params = @create_request
      assert_equal @create_request.dig("incident_id"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.dig("condition_name"),
        description: @create_request.dig("details"),
        urgency: nil,
        thirdparty_id: @create_request.dig("incident_id"),
        dedup_keys: [@create_request.dig("incident_id")],
        additional_data: [
          AdditionalDatum.new(format: "text", label: "Account Name", value: @create_request.dig("account_name")),
          AdditionalDatum.new(format: "text", label: "Incident URL", value: @create_request.dig("incident_url"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
