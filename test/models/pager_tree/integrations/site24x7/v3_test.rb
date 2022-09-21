require "test_helper"

module PagerTree::Integrations
  class Site24x7::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:site24x7_v3)

      @create_request = {
        triggered_at: "2016-05-24T20:10:57.657259407Z",
        MONITOR_DASHBOARD_LINK: "https://www.site24x7.com/app/client#/home/monitors/285731000000025126/Summary",
        MONITORTYPE: "URL",
        MONITOR_ID: 285731000000025120,
        STATUS: "DOWN",
        MONITORNAME: "Website-tall-hut-056a2.ngrok.io",
        FAILED_LOCATIONS: "Brisbane-AUS,Nagano-JP,Tokyo-JP,Mumbai-IN,Melbourne-AUS,Istanbul-TR",
        INCIDENT_REASON: "Internal Server Error",
        OUTAGE_TIME_UNIX_FORMAT: "1534790689166",
        MONITORURL: "https://tall-hut-056a2.ngrok.io",
        TIMEZONE: "America/Los_Angeles",
        MONITOR_GROUPNAME: "tall-hut-056a2.ngrok.io, URL-tall-hut-056a2.ngrok.io",
        POLLFREQUENCY: 1,
        INCIDENT_TIME: "August 20, 2018 11:44 AM PDT",
        INCIDENT_TIME_ISO: "2018-08-20T11:44:49-0700",
        RCA_LINK: "https://www.site24x7.com/rca.do?id=qNuxh5..."
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:STATUS] = "UP"

      @other_request = @create_request.deep_dup
      @other_request[:STATUS] = "baaad"
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
      assert_equal @create_request.dig("MONITOR_ID"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: "#{@create_request.dig("MONITORNAME")} is DOWN",
        description: "#{@create_request.dig("MONITORNAME")} is DOWN because #{@create_request.dig("INCIDENT_REASON")}",
        urgency: nil,
        thirdparty_id: @create_request.dig("MONITOR_ID"),
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Site 24x7 Dashboard URL", value: @create_request.dig("MONITOR_DASHBOARD_LINK")),
          AdditionalDatum.new(format: "text", label: "Monitor Name", value: @create_request.dig("MONITORNAME")),
          AdditionalDatum.new(format: "link", label: "Monitor URL", value: @create_request.dig("MONITORURL")),
          AdditionalDatum.new(format: "text", label: "Group Name", value: @create_request.dig("MONITOR_GROUPNAME")),
          AdditionalDatum.new(format: "text", label: "Reason", value: @create_request.dig("INCIDENT_REASON")),
          AdditionalDatum.new(format: "text", label: "Failed Locations", value: @create_request.dig("FAILED_LOCATIONS")),
          AdditionalDatum.new(format: "datetime", label: "Failed At", value: @create_request.dig("INCIDENT_TIME_ISO"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
