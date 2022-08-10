require "test_helper"

module PagerTree::Integrations
  class Mattermost::OutgoingWebhook::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:mattermost_outgoing_webhook_v3)

      @create_request = {
        token: "abc123",
        team_id: "abcdefg",
        team_domain: "team_domain",
        channel_id: "hijklmnop",
        channel_name: "noc-ops-center",
        timestamp: 1656637234966,
        user_id: "qrstuvwxyz",
        user_name: "joe.bob",
        post_id: "0123456789",
        text: "#page_noc cRitical outage on server-1",
        trigger_word: "#page_noc",
        file_ids: ""
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
      # TODO: Check that the third party id comes back as expected
      @integration.adapter_incoming_request_params = @create_request
      assert_equal "#{@create_request.dig("channel_id")}.#{@create_request.dig("timestamp")}", @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request
      thirdparty_id = "#{@create_request.dig("channel_id")}.#{@create_request.dig("timestamp")}"

      true_alert = Alert.new(
        title: @create_request.dig("text"),
        urgency: "critical",
        thirdparty_id: thirdparty_id,
        dedup_keys: [thirdparty_id],
        additional_data: [
          AdditionalDatum.new(format: "text", label: "Trigger", value: @create_request.dig("trigger_word")),
          AdditionalDatum.new(format: "text", label: "Channel", value: @create_request.dig("channel_name")),
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
