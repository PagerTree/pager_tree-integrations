require "test_helper"

module PagerTree::Integrations
  class DeadMansSnitch::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:dead_mans_snitch_v3)

      @create_request = {
        type: "snitch.missing",
        timestamp: "2017-12-15T17:42:31.799Z",
        data: {
          snitch: {
            token: "c2354d53d2",
            name: "Critical System Reports",
            notes: "Useful notes for dealing with the situation",
            tags: ["critical", "reports"],
            status: "missing",
            previous_status: "healthy"
          }
        }
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:type] = "snitch.reporting"
      @resolve_request[:data][:snitch][:status] = "healthy"
      @resolve_request[:data][:snitch][:previous_status] = "missing"

      @other_request = @create_request.deep_dup
      @other_request[:type] = "baaad"
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
      assert_equal @create_request.dig("data", "snitch", "token"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.dig("data", "snitch", "name"),
        description: @create_request.dig("data", "snitch", "notes"),
        urgency: nil,
        thirdparty_id: @create_request.dig("data", "snitch", "token"),
        dedup_keys: [],
        additional_data: [],
        tags: @create_request.dig("data", "snitch", "tags")
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
