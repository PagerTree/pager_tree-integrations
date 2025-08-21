require "test_helper"

module PagerTree::Integrations
  class Scom::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:scom_v3)

      @create_request = {
        "owner": "np",
        "lastModified": "12/24/2015 11:47:16 AM",
        "resolutionState": "New",
        "timeRaised": "12/24/2015 11:47:16 AM",
        "resolutionStateLastModified": "np",
        "workflowId": "{7eba60fd-b179-69a7-3897-47b6753601f2}",
        "category": "Custom",
        "alertId": "{2ba87d56-a7af-4b42-bdcc-eb18486bd8cd}",
        "alertName": "Alert for event 999",
        "priority": "1",
        "severity": "2",
        "createdByMonitor": "false",
        "repeatCount": "0",
        "alertDescription": "np",
        "managedEntitySource": "WIN-RQTU8UB5TU5.pagertreecom.com"
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:resolutionState] = "Closed"

      @other_request = @create_request.deep_dup
      @other_request[:resolutionState] = "Not Present"
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
      assert_equal @create_request[:alertId], @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request[:alertName],
        description: @create_request[:alertDescription],
        urgency: nil,
        thirdparty_id: @create_request[:alertId],
        dedup_keys: [],
        additional_data: []
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
