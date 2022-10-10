require "test_helper"

module PagerTree::Integrations
  class Slack::Webhook::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:slack_webhook_v3)

      @create_request = {
        token: "bclb6tJAuYwTk59ywGQ3rwFx",
        team_id: "T3R0C6ABC",
        team_domain: "pagertree",
        service_id: "398047594123",
        channel_id: "C014E5UMZ1S",
        channel_name: "production",
        timestamp: "1664813178.766549",
        user_id: "U3QTH7ABC",
        user_name: "austinrmiller1991",
        text: "outage check servers high",
        trigger_word: "outage"
      }.with_indifferent_access
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
    end

    test "adapter_thirdparty_id" do
      @integration.adapter_incoming_request_params = @create_request
      assert_equal [@create_request.dig("channel_id"), @create_request.dig("timestamp")].join("."), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.dig("text"),
        urgency: "high",
        thirdparty_id: [@create_request.dig("channel_id"), @create_request.dig("timestamp")].join("."),
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "text", label: "Trigger", value: @create_request.dig("trigger_word")),
          AdditionalDatum.new(format: "text", label: "Channel", value: @create_request.dig("channel")),
          AdditionalDatum.new(format: "text", label: "User", value: @create_request.dig("user_name"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    test "blocking_incoming" do
      @blocked_request = @create_request.deep_dup
      @integration.option_token = "abc123"
      assert @integration.adapter_should_block_incoming?(OpenStruct.new({params: {"token" => ""}}))
      assert_not @integration.adapter_should_block_incoming?(OpenStruct.new({params: {"token" => "abc123"}}))
    end
  end
end
