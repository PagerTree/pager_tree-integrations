require "test_helper"

module PagerTree::Integrations
  class Zabbix::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:zabbix_v3)

      @create_request = {
        event_id: "23",
        event_source: "0",
        event_nseverity: "4",
        trigger_id: "25066",
        zabbix_url: "https://abc123.zabbix.cloud",
        title: "Problem: https://statuscode.app/ Status",
        description: "Problem started at 17:45:41 on 2025.08.20\r\nProblem name: https://statuscode.app/ Status\r\nHost: Zabbix server\r\nSeverity: High\r\nOperational data: 500\r\nOriginal problem ID: 23\r\n",
        event_tags: "abc,123",
        event_value: "1"
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:event_value] = "0"

      @other_request = @create_request.deep_dup
      @other_request[:event_value] = "2"
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
      assert_equal "25066", @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request[:title],
        description: "<pre>#{@create_request[:description]}</pre>",
        urgency: "high",
        thirdparty_id: @create_request[:trigger_id],
        dedup_keys: [],
        tags: ["abc", "123"],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Zabbix URL", value: "https://abc123.zabbix.cloud/tr_events.php?triggerid=25066&eventid=23")
        ]
      )

      assert @integration.option_map_urgency
      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
