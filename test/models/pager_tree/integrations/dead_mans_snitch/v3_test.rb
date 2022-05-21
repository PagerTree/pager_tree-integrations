require "test_helper"

module PagerTree::Integrations
  class DeadMansSnitch::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:dead_mans_snitch_v3)

      # TODO: Write some requests to test the integration
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
      # TODO: Check some sane defaults your integration should have
      assert @integration.adapter_supports_incoming?
      assert @integration.adapter_incoming_can_defer?
      assert_not @integration.adapter_supports_outgoing?
      assert @integration.adapter_show_alerts?
      assert @integration.adapter_show_logs?
      assert_not @integration.adapter_show_outgoing_webhook_delivery?
    end

    test "adapter_actions" do
      # TODO: Check that the adapter_actions returns expected results based on the inputs
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
      # TODO: Check tthe entire transform
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.dig("data", "snitch", "name"),
        description: @create_request.dig("data", "snitch", "notes"),
        urgency: nil,
        thirdparty_id: @create_request.dig("data", "snitch", "token"),
        dedup_keys: [@create_request.dig("data", "snitch", "token")],
        additional_data: [],
        tags: @create_request.dig("data", "snitch", "tags")
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
