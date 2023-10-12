require "test_helper"

module PagerTree::Integrations
  class LogicMonitor::V3Test < ActiveSupport::TestCase
    include Integrateable
    include ActiveJob::TestHelper

    setup do
      @integration = pager_tree_integrations_integrations(:logic_monitor_v3)

      @create_request = {
        alertid: "LMS22",
        alertstatus: "active",
        datasource: "WinVolumeUsage-C:\\",
        datapoint: "PercentUsed",
        date: "2014-05-02 14:21:40 PDT",
        dsdesc: "Monitors space usage on logical volumes.",
        dsidesc: nil,
        datapointdesc: "Percentage Used on the volume",
        group: "group1,group2",
        host: "pagertree-test-server",
        hostdesc: "Server used for testing PagerTree integrations",
        instance: "C:\\",
        level: "warning",
        duration: "1465",
        threshold: "10",
        eventsource: "WinVolumeUsage-C:\\",
        eventlogfile: "Application",
        eventtype: "information",
        eventmsg: "Percentage used on the volume exceeded 80%",
        eventlogmsg: "Remaining capacity(1456750MB) of volume C:\\ is lower than 25%",
        eventcode: "1847502394",
        eventuser: "test-user",
        value: "83",
        batchdesc: "Monitors space usage on logical volumes everyday.",
        hostips: "123.456.789.012",
        hosturl: "https://pagertree-test-server.net/",
        service: "webservice",
        alerttype: "error",
        agent: "pagertree-test-server",
        checkpoint: "1879234",
        hostinfo: nil,
        servicedetail: nil,
        serviceurl: "https://pagertree-test-server.net/",
        servicegroup: "Functional Testing",
        clearvalue: "1",
        internalid: "1234567890"
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:alertstatus] = "clear"

      @other_request = @create_request.deep_dup
      @other_request[:alertstatus] = "baaad"
    end

    test "sanity" do
      assert @integration.adapter_supports_incoming?
      assert @integration.adapter_incoming_can_defer?
      assert @integration.adapter_supports_outgoing?
      assert @integration.adapter_show_alerts?
      assert @integration.adapter_show_logs?
      assert @integration.adapter_show_outgoing_webhook_delivery?
    end

    test "outgoing_interest" do
      assert_not @integration.adapter_outgoing_interest?(:alert_created)
      assert @integration.adapter_outgoing_interest?(:alert_acknowledged)
      assert_not @integration.adapter_outgoing_interest?(:foo)
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
      assert_equal @create_request.dig("internalid"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.dig("eventmsg"),
        description: @create_request.dig("eventlogmsg"),
        urgency: "medium",
        thirdparty_id: @create_request.dig("internalid"),
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "text", label: "Host", value: @create_request.dig("host")),
          AdditionalDatum.new(format: "text", label: "Service", value: @create_request.dig("service"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    test "can_process_outgoing" do
      assert_no_performed_jobs

      expected_payload = {
        "ackComment" => "Acknowledged by test-user"
      }

      outgoing_event = OutgoingEvent.new
      outgoing_event.event_name = :alert_acknowledged
      outgoing_event.alert = OpenStruct.new(
        thirdparty_id: "1234567890",
        foo: "bar",
        source: @integration
      )
      outgoing_event.changes = [{
        before: {
          foo: "baz"
        },
        after: {
          foo: "bar"
        }
      }]
      outgoing_event.account_user = OpenStruct.new(
        name: "test-user"
      )

      @integration.adapter_outgoing_event = outgoing_event
      outgoing_webhook_delivery = @integration.adapter_process_outgoing

      assert_enqueued_jobs 1

      assert_equal "https://#{@integration.option_logic_monitor_account_name}.logicmonitor.com/santaba/rest/alert/alerts/#{outgoing_event.alert.thirdparty_id}/ack", outgoing_webhook_delivery.url
      assert_equal :queued.to_s, outgoing_webhook_delivery.status
      assert_equal expected_payload.to_json, outgoing_webhook_delivery.body.to_json
      assert outgoing_webhook_delivery.options.dig("headers", "Authorization").starts_with?("LMv1 #{@integration.option_access_id}:")
    end
  end
end
