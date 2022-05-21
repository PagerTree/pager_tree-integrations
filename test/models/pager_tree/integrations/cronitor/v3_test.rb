require "test_helper"

module PagerTree::Integrations
  class Cronitor::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:cronitor_v3)

      @create_request = {
        id: "ksQC7a",
        monitor: "Test Hearbeat",
        type: "Alert",
        description: "Did not send an event at the expected time.\nEnvironment: Production\nLast ping: May 21, 10:07:16 UTC\nExpected: May 21, 10:09:36 UTC\nSchedule: every 1 minute",
        rule: "not_on_schedule"
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request["type"] = "Recovery"

      @other_request = @create_request.deep_dup
      @other_request["type"] = "baad"
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
      assert_equal @create_request.id, @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.monitor,
        urgency: nil,
        thirdparty_id: @create_request.id,
        dedup_keys: [@create_request.id],
        additional_data: [
          AdditionalDatum.new(format: "text", label: "Rule Violated", value: @create_request.rule)
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
