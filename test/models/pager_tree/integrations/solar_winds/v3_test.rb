require "test_helper"

module PagerTree::Integrations
  class SolarWinds::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:solar_winds_v3)

      @create_request = {
        ActionType: "Create",
        NodeName: "EOC4500X-Core",
        AlertID: "156",
        AlertMessage: "CriticalEIGRP - Neighbor Down Neighbor 10.0.0.105 on EOC4500X-Core went down.",
        AlertDescription: "This alert is triggered, if any routing neighbor on node changes its status to down.",
        AlertDetailsUrl: "",
        AcknowledgeUrl: "",
        AlertTriggerCount: "0",
        AlertTriggerTime: "Never",
        Severity: ""
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:ActionType] = "resolve"

      @other_request = @create_request.deep_dup
      @other_request[:ActionType] = "baaad"
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
      assert_equal @create_request.dig("AlertID"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.dig("AlertMessage"),
        description: @create_request.dig("AlertDescription"),
        urgency: nil,
        thirdparty_id: @create_request.dig("AlertID"),
        dedup_keys: [@create_request.dig("AlertID")],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Alert Details URL", value: @create_request.dig("AlertDetailsURL")),
          AdditionalDatum.new(format: "text", label: "Node", value: @create_request.dig("NodeName"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
