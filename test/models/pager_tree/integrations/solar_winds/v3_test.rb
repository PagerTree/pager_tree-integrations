require "test_helper"

module PagerTree::Integrations
  class SolarWinds::V3Test < ActiveSupport::TestCase
    include Integrateable
    include ActiveJob::TestHelper

    setup do
      @integration = pager_tree_integrations_integrations(:solar_winds_v3)

      @create_request = {
        ActionType: "Create",
        NodeName: "EOC4500X-Core",
        AlertID: "156",
        AlertMessage: "CriticalEIGRP - Neighbor Down Neighbor 10.0.0.105 on EOC4500X-Core went down.",
        AlertDescription: "This alert is triggered, if any routing neighbor on node changes its status to down.",
        AlertDetailsUrl: "",
        AcknowledgeUrl: "",
        AlertTriggerCount: "0",
        AlertTriggerTime: "Never",
        Severity: ""
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:ActionType] = "resolve"

      @other_request = @create_request.deep_dup
      @other_request[:ActionType] = "baaad"
    end

    test "sanity" do
      assert @integration.adapter_supports_incoming?
      assert @integration.adapter_incoming_can_defer?
      assert @integration.adapter_supports_outgoing?
      assert @integration.adapter_show_alerts?
      assert @integration.adapter_show_logs?
      assert @integration.adapter_show_outgoing_webhook_delivery?
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
      assert_equal @create_request.dig("AlertID"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.dig("AlertMessage"),
        description: @create_request.dig("AlertDescription"),
        urgency: nil,
        thirdparty_id: @create_request.dig("AlertID"),
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Alert Details URL", value: @create_request.dig("AlertDetailsURL")),
          AdditionalDatum.new(format: "text", label: "Node", value: @create_request.dig("NodeName"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    test "outgoing_interest" do
      assert_not @integration.adapter_outgoing_interest?(:alert_created)
      assert_not @integration.adapter_outgoing_interest?(:foo)
      assert_not @integration.adapter_outgoing_interest?(:alert_acknowledged)

      @integration.option_alert_acknowledged = true
      assert @integration.adapter_outgoing_interest?(:alert_acknowledged)
    end

    test "outgoing_options_validation" do
      assert_equal false, @integration.option_alert_acknowledged
      assert @integration.valid?

      @integration.option_alert_acknowledged = true
      assert_not @integration.valid?

      @integration.option_server_url = "https://example.com:17774"
      assert_not @integration.valid?

      @integration.option_server_username = "username"
      assert_not @integration.valid?

      @integration.option_server_password = "password"
      assert @integration.valid?

      @integration.option_proxy_url = "http://proxyuser:proxypass@proxy.com:3128"
      assert @integration.valid?
    end

    test "can_process_outgoing" do
      @integration.option_server_url = "https://example.com:17774"
      @integration.option_server_username = "username"
      @integration.option_server_password = "password"
      @integration.option_proxy_url = "http://proxyuser:proxypass@proxy.com:3128"

      assert_no_performed_jobs

      data = {
        event_name: :alert_acknowledged,
        alert: JSON.parse({
          foo: "bar",
          source_log: {
            message: {
              params: {
                ActionType: "Create",
                NodeName: "ABC123.example.com",
                AlertID: "123",
                AlertMessage: "CPU was triggered.",
                AlertDescription: "",
                AlertDetailsUrl: "https://example.com/Orion/View.aspx?NetObject=AAT:24565",
                AcknowledgeUrl: "https://example.com/Orion/Netperfmon/AckAlert.aspx?ObjID=24565",
                AlertTriggerCount: "1449",
                AlertTriggerTime: "Friday, March 21, 2025 8:57 AM",
                Severity: "Critical"
              }
            }
          }
        }.to_json, object_class: OpenStruct),
        changes: [{
          before: {
            foo: "baz"
          },
          after: {
            foo: "bar"
          }
        }]
      }

      data[:alert].source = @integration

      @integration.adapter_outgoing_event = OutgoingEvent.new(**data)
      outgoing_webhook_delivery = @integration.adapter_process_outgoing

      assert_enqueued_jobs 1

      server_uri = URI.parse(@integration.option_server_url)
      assert_equal "#{server_uri.origin}/SolarWinds/InformationService/v3/Json/Invoke/Orion.AlertActive/Acknowledge", outgoing_webhook_delivery.url
      assert_equal "Acknowledged by ", outgoing_webhook_delivery.body.dig("notes")
      assert_equal Base64.strict_encode64("#{@integration.option_server_username}:#{@integration.option_server_password}"), outgoing_webhook_delivery.httparty_opts.with_indifferent_access.dig("headers", "Authorization")
      assert_equal @integration.option_proxy_url, outgoing_webhook_delivery.proxy_url
    end
  end
end
