require "test_helper"

module PagerTree::Integrations
  class Hyperping::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:hyperping_v3)

      @create_request = {
        event: "check.down",
        check: {
          url: "https://js.stripe.com/v3/",
          status: 502,
          down: true,
          date: 1556506024291,
          downtime: 1
        },
        pings: [
          {
            original: true,
            location: "london",
            status: 502,
            statusMessage: "Bad Gateway"
          },
          {
            original: false,
            location: "paris",
            status: 502,
            statusMessage: "Bad Gateway"
          },
          {
            original: false,
            location: "frankfurt",
            status: 502,
            statusMessage: "Bad Gateway"
          }
        ]
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:event] = "check.up"

      @other_request = @create_request.deep_dup
      @other_request[:event] = "check.baaad"
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
      assert_equal @create_request.dig("check", "url"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.dig("check", "url") + " is DOWN",
        urgency: nil,
        thirdparty_id: @create_request.dig("check", "url"),
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "URL", value: @create_request.dig("check", "url")),
          AdditionalDatum.new(format: "text", label: "Status Code", value: @create_request.dig("check", "status")),
          AdditionalDatum.new(format: "datetime", label: "Down Since", value: Time.at(@create_request.dig("check", "date") / 1000).utc.to_datetime)
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
