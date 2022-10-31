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

      @create_request_2 = {
        id: "b6137c61-0e27-496d-bd9b-335c98c155eb",
        issueUrl: "https://one.eu.newrelic.com/launcher/nrai.launcher?pane=123",
        title: "Error percentage > 2.5% for at least 5 minutes on 'HIGHREV-pr-TS'",
        priority: "HIGH",
        impactedEntities: [
          "HIGHREV-pr-TS"
        ],
        totalIncidents: 1,
        state: "CREATED",
        trigger: "INCIDENT_ADDED",
        isCorrelated: false,
        createdAt: 1665924858970,
        updatedAt: 1665924858970,
        sources: [
          "newrelic"
        ],
        alertPolicyNames: [
          "Error Percentage (High) Policy"
        ],
        alertConditionNames: [
          "Error Percentage (High) threshold"
        ],
        workflowName: "DBA Team workflow"
      }.with_indifferent_access

      @create_request_3 = @create_request_2.deep_dup
      @create_request_3["state"] = "ACTIVATED"

      @acknowledge_request = @create_request.deep_dup
      @acknowledge_request[:event_type] = "INCIDENT_ACKNOWLEDGED"

      @resolve_request = @create_request.deep_dup
      @resolve_request[:event_type] = "INCIDENT_RESOLVED"

      @resolve_request_2 = @create_request_2.deep_dup
      @resolve_request_2[:state] = "CLOSED"

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

      @integration.adapter_incoming_request_params = @create_request_2
      assert_equal :create, @integration.adapter_action

      @integration.adapter_incoming_request_params = @create_request_3
      assert_equal :create, @integration.adapter_action

      @integration.adapter_incoming_request_params = @acknowledge_request
      assert_equal :acknowledge, @integration.adapter_action

      @integration.adapter_incoming_request_params = @resolve_request
      assert_equal :resolve, @integration.adapter_action

      @integration.adapter_incoming_request_params = @resolve_request_2
      assert_equal :resolve, @integration.adapter_action

      @integration.adapter_incoming_request_params = @other_request
      assert_equal :other, @integration.adapter_action
    end

    test "adapter_thirdparty_id" do
      @integration.adapter_incoming_request_params = @create_request
      assert_equal @create_request.dig("incident_id"), @integration.adapter_thirdparty_id

      @integration.adapter_incoming_request_params = @create_request_2
      assert_equal @create_request_2.dig("id"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.dig("condition_name"),
        description: @create_request.dig("details"),
        urgency: nil,
        thirdparty_id: @create_request.dig("incident_id"),
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "text", label: "Account Name", value: @create_request.dig("account_name")),
          AdditionalDatum.new(format: "link", label: "Incident URL", value: @create_request.dig("incident_url")),
          AdditionalDatum.new(format: "link", label: "Issue URL", value: @create_request.dig("issueUrl"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    test "adapter_process_create_2" do
      @integration.adapter_incoming_request_params = @create_request_2

      true_alert = Alert.new(
        title: @create_request_2.dig("title"),
        description: nil,
        urgency: nil,
        thirdparty_id: @create_request_2.dig("id"),
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "text", label: "Account Name", value: @create_request_2.dig("account_name")),
          AdditionalDatum.new(format: "link", label: "Incident URL", value: @create_request_2.dig("incident_url")),
          AdditionalDatum.new(format: "link", label: "Issue URL", value: @create_request_2.dig("issueUrl"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
