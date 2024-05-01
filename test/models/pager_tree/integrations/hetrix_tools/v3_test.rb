require "test_helper"

module PagerTree::Integrations
  class HetrixTools::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:hetrix_tools_v3)

      # https://docs.hetrixtools.com/uptime-monitoring-webhook-notifications/
      @uptime_request = {
        monitor_id: "ThisWillBeTheMonitorID32CharLong",
        monitor_name: "Test Monitor Label",
        monitor_target: "http:\/\/this-is-a-test.com\/",
        monitor_type: "website",
        monitor_category: "Test Category",
        monitor_status: "offline",
        timestamp: 1499666192,
        monitor_errors: {
          "New York": "http code 403",
          "San Francisco": "http code 403",
          Dallas: "timeout",
          Amsterdam: "http code 403",
          London: "http code 403",
          Frankfurt: "http code 403",
          Singapore: "timeout",
          Sydney: "http code 403",
          "Sao Paulo": "http code 403",
          Tokyo: "keyword not found",
          Mumbai: "http code 403",
          Moscow: "keyword not found"
        }
      }.with_indifferent_access

      # https://docs.hetrixtools.com/blacklist-monitoring-webhook-notifications/
      @blacklist_request = {_json: [
        {
          monitor: "98.88.89.102",
          label: "some label",
          blacklisted_before: "7",
          blacklisted_now: "6",
          blacklisted_on: [
            {
              rbl: "bl.nszones.com",
              delist: "http://www.nszones.com/contact.shtml"
            },
            {
              rbl: "bl.score.senderscore.com",
              delist: "https://www.senderscore.org/blacklistlookup/"
            },
            {
              rbl: "cidr.bl.mcafee.com",
              delist: "https://kc.mcafee.com/corporate/index?page=content&id=KB53783"
            },
            {
              rbl: "dyn.nszones.com",
              delist: "http://db.nszones.com/dyn.ip?98.88.89.102"
            },
            {
              rbl: "pbl.spamhaus.org",
              delist: "https://www.spamhaus.org/query/ip/98.88.89.102"
            },
            {
              rbl: "zen.spamhaus.org",
              delist: "https://www.spamhaus.org/query/ip/98.88.89.102"
            }
          ],
          links: {
            report_link: "https://hetrixtools.com/report/blacklist/c855b5712bd63a3c8153690b56d5385e/",
            whitelabel_report_link: "http://status.hetrixtools.com/report/blacklist/c855b5712bd63a3c8153690b56d5385e/"
          }
        },
        {
          monitor: "190.129.206.24",
          label: "another label",
          blacklisted_before: "2",
          blacklisted_now: "0",
          blacklisted_on: nil,
          links: {
            report_link: "https://hetrixtools.com/report/blacklist/4255d1931a5c5547a0fce88e6cdff008/",
            whitelabel_report_link: "http://status.hetrixtools.com/report/blacklist/4255d1931a5c5547a0fce88e6cdff008/"
          }
        }
      ]}.with_indifferent_access

      @resource_usage_request = {
        monitor_id: "ThisWillBeTheMonitorID32CharLong",
        monitor_name: "Test Monitor Label",
        timestamp: 1499666613,
        resource_usage: {
          resource_type: "cpu",
          current_usage: "24.60",
          average_usage: "25.29",
          average_minutes: "3"
        }
      }.with_indifferent_access

      @resolve_request = @uptime_request.deep_dup
      @resolve_request["monitor_status"] = "online"
    end

    test "sanity" do
      assert @integration.adapter_supports_incoming?
      assert @integration.adapter_incoming_can_defer?
      assert_not @integration.adapter_supports_outgoing?
      assert @integration.adapter_show_alerts?
      assert @integration.adapter_show_logs?
      assert_not @integration.adapter_show_outgoing_webhook_delivery?
    end

    test "adapter_action_uptime_create" do
      @integration.adapter_incoming_request_params = @uptime_request
      assert_equal :create, @integration.adapter_action
    end

    test "adapter_action_uptime_resolve" do
      @integration.adapter_incoming_request_params = @resolve_request
      assert_equal :resolve, @integration.adapter_action
    end

    test "adapter_action_blacklist_create" do
      @integration.adapter_incoming_request_params = @blacklist_request
      assert_equal :create, @integration.adapter_action
    end

    test "adapter_action_resource_usage_create" do
      @integration.adapter_incoming_request_params = @resource_usage_request
      assert_equal :create, @integration.adapter_action
    end

    test "adapter_thirdparty_id_uptime" do
      @integration.adapter_incoming_request_params = @uptime_request
      assert_equal @uptime_request.dig("monitor_id"), @integration.adapter_thirdparty_id
    end

    test "adapter_thirdparty_id_blacklist" do
      @integration.adapter_incoming_request_params = @blacklist_request
      assert_equal 32, @integration.adapter_thirdparty_id.length # each hex is 2 chars
    end

    test "adapter_thirdparty_id_resource_usage" do
      @integration.adapter_incoming_request_params = @resource_usage_request
      assert_equal 32, @integration.adapter_thirdparty_id.length # each hex is 2 chars
    end

    test "adapter_process_create_uptime" do
      @integration.adapter_incoming_request_params = @uptime_request

      true_alert = Alert.new(
        title: "#{@uptime_request.dig("monitor_name")} is #{@uptime_request.dig("monitor_status")}",
        description: "<p>#{@uptime_request.dig("monitor_target")} is #{@uptime_request.dig("monitor_status")}</p>" + @uptime_request.dig("monitor_errors").map { |k, v| "<p>#{k}: #{v}</p>" }.join(""),
        urgency: nil,
        thirdparty_id: @uptime_request.dig("monitor_id"),
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "datetime", label: "Timestamp", value: Time.at(@uptime_request.dig("timestamp"))),
          AdditionalDatum.new(format: "text", label: "Monitor Type", value: @uptime_request.dig("monitor_type")),
          AdditionalDatum.new(format: "link", label: "Monitor Target", value: @uptime_request.dig("monitor_target"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    test "adapter_process_create_blacklist" do
      @integration.adapter_incoming_request_params = @blacklist_request

      true_alert = Alert.new(
        title: "Blacklist Alert",
        description: @blacklist_request.dig("_json").map { |x| "#{x["monitor"]} (#{x["blacklisted_now"]})" }.join("<br/>"),
        urgency: nil,
        thirdparty_id: nil,
        dedup_keys: [],
        additional_data: []
      )

      actual = @integration.adapter_process_create
      actual.thirdparty_id = nil
      assert_equal true_alert.to_json, actual.to_json
    end

    test "adapter_process_create_resource_usage" do
      @integration.adapter_incoming_request_params = @resource_usage_request

      true_alert = Alert.new(
        title: "#{@resource_usage_request.dig("monitor_name")} usage alert",
        description: [
          "<p>Resource Type: #{@resource_usage_request.dig("resource_usage", "resource_type")}</p>",
          "<p>Current Usage: #{@resource_usage_request.dig("resource_usage", "current_usage")}</p>",
          "<p>Average Usage: #{@resource_usage_request.dig("resource_usage", "average_usage")} / #{@resource_usage_request.dig("resource_usage", "average_minutes")}m</p>"
        ].join(""),
        urgency: nil,
        thirdparty_id: nil,
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "text", label: "Resource Type", value: @resource_usage_request.dig("resource_usage", "resource_type")),
          AdditionalDatum.new(format: "text", label: "Current Usage", value: @resource_usage_request.dig("resource_usage", "current_usage"))
        ]
      )

      actual = @integration.adapter_process_create
      actual.thirdparty_id = nil
      assert_equal true_alert.to_json, actual.to_json
    end

    test "blocking_incoming" do
      assert @integration.option_authentication_token.blank?
      assert_not @integration.adapter_should_block_incoming?(OpenStruct.new({headers: {"Authorization" => ""}}))

      @integration.option_authentication_token = "abc123456"
      assert @integration.adapter_should_block_incoming?(OpenStruct.new({headers: {"Authorization" => ""}}))
      assert_not @integration.adapter_should_block_incoming?(OpenStruct.new({headers: {"Authorization" => "Bearer abc123456"}}))
    end
  end
end
