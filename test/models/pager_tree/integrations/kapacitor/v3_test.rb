require "test_helper"

module PagerTree::Integrations
  class Kapacitor::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:kapacitor_v3)

      @create_request = {
        id: 123,
        level: "WARN",
        message: "CPU usage high",
        details: "CPU has gone over 90% for 1m"
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:level] = "OK"
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
    end

    test "adapter_thirdparty_id" do
      @integration.adapter_incoming_request_params = @create_request
      assert_equal @create_request.dig("id"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.dig("message"),
        description: @create_request.dig("details"),
        urgency: "medium",
        thirdparty_id: @create_request.dig("id"),
        dedup_keys: [@create_request.dig("id")],
        additional_data: []
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
