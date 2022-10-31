require "test_helper"

module PagerTree::Integrations
  class ElastAlert::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:elast_alert_v3)

      @create_request = {
        event_type: "create",
        Id: "1",
        Title: "A title",
        Description: "Some description"
      }.with_indifferent_access

      @acknowledge_request = @create_request.deep_dup
      @acknowledge_request[:event_type] = "acknowledge"

      @resolve_request = @create_request.deep_dup
      @resolve_request[:event_type] = "resolve"

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

      @integration.adapter_incoming_request_params = @acknowledge_request
      assert_equal :acknowledge, @integration.adapter_action

      @integration.adapter_incoming_request_params = @resolve_request
      assert_equal :resolve, @integration.adapter_action

      @integration.adapter_incoming_request_params = @other_request
      assert_equal :other, @integration.adapter_action
    end

    test "adapter_thirdparty_id" do
      @integration.adapter_incoming_request_params = @create_request
      assert_equal @create_request.dig("Id"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.dig("Title"),
        description: @create_request.dig("Description"),
        thirdparty_id: @create_request.dig("Id"),
        dedup_keys: [],
        additional_data: []
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
