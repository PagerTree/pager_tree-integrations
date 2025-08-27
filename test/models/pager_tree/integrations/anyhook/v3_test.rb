require "test_helper"

module PagerTree::Integrations
  class Anyhook::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:anyhook_v3)

      # TODO: Write some requests to test the integration
      @create_request = {
        "triggered_at": "2016-05-24T20:10:57.657259407Z",
        "state": "triggered",
        "alert": {
          "id": 9,
          "type": "time_total",
          "stat": "avg",
          "window_duration": 5,
          "value": 2500,
          "op": "gt"
        },
        "check": {
          "id": 80,
          "name": "Axe Search",
          "method": "GET",
          "protocol": "http",
          "url": "www.axemusic.com/catalogsearch/result/?cat=0&q=sm58",
          "apdex_threshold": 700
        },
        "value": 2724
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:state] = "resolved"

      @other_request = @create_request.deep_dup
      @other_request[:state] = "baaad"
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
      # TODO: Check that the third party id comes back as expected
      @integration.adapter_incoming_request_params = @create_request
      assert_equal 9, @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      # TODO: Check tthe entire transform
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: "Axe Search triggered",
        urgency: nil,
        thirdparty_id: 9,
        dedup_keys: [9],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "URL", value: "http://www.axemusic.com/catalogsearch/result/?cat=0&q=sm58"),
          AdditionalDatum.new(format: "text", label: "Method", value: "GET"),
          AdditionalDatum.new(format: "datetime", label: "Triggered At", value: "2016-05-24T20:10:57.657259407Z")
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
