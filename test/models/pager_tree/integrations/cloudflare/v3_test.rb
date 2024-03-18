require "test_helper"

module PagerTree::Integrations
  class Cloudflare::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:cloudflare_v3)

      @create_request = {
        name: "Testing Webhook",
        text: "Requests to the following zone(s) have been failing for at least 5 minutes: zone-name",
        data: {
          unreachable_zones: [
            {
              zone_name: "zone-name",
              host: ""
            }
          ]
        },
        ts: 1710782148,
        account_id: "abc123",
        policy_id: "def456",
        alert_type: "real_origin_monitoring"
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
      assert @integration.adapter_thirdparty_id.present?
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: "Requests to the following zone(s) have been failing for at least 5 ...",
        description: ActionController::Base.helpers.simple_format(@create_request["text"]),
        urgency: nil,
        thirdparty_id: @integration.adapter_thirdparty_id,
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "datetime", label: "Timestamp", value: Time.at(1710782148).utc.to_datetime),
          AdditionalDatum.new(format: "text", label: "Alert Type", value: "real_origin_monitoring"),
          AdditionalDatum.new(format: "text", label: "Account ID", value: "abc123"),
          AdditionalDatum.new(format: "text", label: "Policy ID", value: "def456")
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    test "blocking_incoming" do
      @blocked_request = @create_request.deep_dup
      @integration.option_webhook_secret = "abc123"
      assert @integration.adapter_should_block_incoming?(OpenStruct.new({headers: {"cf-webhook-auth" => ""}}))
      assert_not @integration.adapter_should_block_incoming?(OpenStruct.new({headers: {"cf-webhook-auth" => "abc123"}}))
    end
  end
end
