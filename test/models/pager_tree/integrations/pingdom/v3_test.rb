require "test_helper"

module PagerTree::Integrations
  class Pingdom::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:pingdom_v3)

      @create_request = {
        check_id: 12345,
        check_name: "Name of HTTP check",
        check_type: "HTTP",
        check_params: {
          basic_auth: false,
          encryption: true,
          full_url: "https://www.example.com/path",
          header: "User-Agent:Pingdom.com_bot",
          hostname: "www.example.com",
          ipv6: false,
          port: 443,
          url: "/path"
        },
        tags: [
          "example_tag"
        ],
        previous_state: "UP",
        current_state: "DOWN",
        importance_level: "HIGH",
        state_changed_timestamp: 1451610061,
        state_changed_utc_time: "2016-01-01T01:01:01",
        long_description: "Long error message",
        description: "Short error message",
        first_probe: {
          ip: "123.4.5.6",
          ipv6: "2001:4800:1020:209::5",
          location: "Stockholm, Sweden"
        },
        second_probe: {
          ip: "123.4.5.6",
          ipv6: "2001:4800:1020:209::5",
          location: "Austin, US",
          version: 1
        }
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:previous_state] = "DOWN"
      @resolve_request[:current_state] = "UP"

      @other_request = @create_request.deep_dup
      @other_request[:previous_state] = "baaad"
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
      assert_equal @create_request.dig("check_id"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: [@create_request.dig("check_name"), @create_request.dig("current_state")].join(" "),
        description: @create_request.dig("description"),
        urgency: nil,
        thirdparty_id: @create_request.dig("check_id"),
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Full URL", value: @create_request.dig("check_params", "full_url")),
          AdditionalDatum.new(format: "text", label: "Importance Level", value: @create_request.dig("importance_level")),
          AdditionalDatum.new(format: "text", label: "Custom Message", value: @create_request.dig("custom_message"))
        ],
        tags: @create_request.dig("tags")
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
