require "test_helper"

module PagerTree::Integrations
  class CustomWebhook::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:custom_webhook_v3)

      @yml_definition = <<~YAML
        ---
        rules:
          - match:
              log.data.alertTypeFriendlyName: { $regex: "^down$", $options: "i" }
            actions:
              - type: create
                title: "{{log.data.monitorFriendlyName}} is DOWN"
                description: "{{log.data.monitorFriendlyName}} is DOWN because {{log.data.alertDetails}}"
                urgency: "{{log.data.urgency}}"
                dedup_keys: "xyz"
                incident: "true"
                incident_severity: "SEV-2"
                incident_message: "Please join the bridge"
                tags:
                - monitor
                - website
                meta:
                  key1: value1
                  key2: value2
                thirdparty_id: "{{log.data.monitorID}}"
                additional_data:
                  - format: link
                    label: Monitor URL
                    value: "{{log.data.monitorURL}}"
                  - format: datetime
                    label: Triggered At
                    value: "{{log.data.alertDateTime}}"
          
          - match:
              log.data.alertTypeFriendlyName: { $regex: "^pending$", $options: "i" }
            actions:
              - type: acknowledge

          - match:
              log.data.alertTypeFriendlyName: { $regex: "^up$", $options: "i" }
            actions:
              - type: resolve
                thirdparty_id: "{{log.data.monitorID}}"
          
          - match:
              log.data.alertTypeFriendlyName: "Paused"
            actions:
              - type: ignore
      YAML

      @create_request = {
        "monitorID" => "12345",
        "alertTypeFriendlyName" => "Down",
        "monitorFriendlyName" => "My Website",
        "alertDetails" => "Connection timeout",
        "monitorURL" => "https://example.com",
        "urgency" => "high",
        "alertDateTime" => 1733126400
      }.with_indifferent_access

      @acknowledge_request = @create_request.deep_dup
      @acknowledge_request["alertTypeFriendlyName"] = "Pending"

      @resolve_request = @create_request.deep_dup
      @resolve_request["alertTypeFriendlyName"] = "Up"

      @other_request = @create_request.deep_dup
      @other_request["alertTypeFriendlyName"] = "Paused"

      @headers = {
        "User-Agent" => "UptimeRobot/1.0",
        "Content-Type" => "application/json"
      }

      @integration.option_custom_definition = @yml_definition
      @integration.adapter_incoming_deferred_request = OpenStruct.new({
        url: "https://integration.url/int_123",
        method: "post",
        headers: @headers,
        body: @create_request,
        remote_ip: "127.0.0.1"
      })
    end

    test "sanity" do
      assert @integration.adapter_supports_incoming?
      assert @integration.adapter_incoming_can_defer?
      assert_not @integration.adapter_supports_outgoing?
      assert @integration.adapter_show_alerts?
      assert @integration.adapter_show_logs?
      assert_not @integration.adapter_show_outgoing_webhook_delivery?
    end

    test "adapter_action_create" do
      VCR.use_cassette("custom_webhook_v3_adapter_action_create") do
        @integration.adapter_incoming_request_params = @create_request
        @integration.adapter_incoming_deferred_request.body = @create_request
        assert_equal :create, @integration.adapter_action
      end
    end

    test "adapter_action_acknowledge" do
      VCR.use_cassette("custom_webhook_v3_adapter_action_acknowledge") do
        @integration.adapter_incoming_request_params = @acknowledge_request
        @integration.adapter_incoming_deferred_request.body = @acknowledge_request
        assert_equal :acknowledge, @integration.adapter_action
      end
    end
    test "adapter_action_resolve" do
      VCR.use_cassette("custom_webhook_v3_adapter_action_resolve") do
        @integration.adapter_incoming_request_params = @resolve_request
        @integration.adapter_incoming_deferred_request.body = @resolve_request
        assert_equal :resolve, @integration.adapter_action
      end
    end
    test "adapter_action_other" do
      VCR.use_cassette("custom_webhook_v3_adapter_action_other") do
        @integration.adapter_incoming_request_params = @other_request
        @integration.adapter_incoming_deferred_request.body = @other_request
        assert_equal :other, @integration.adapter_action
      end
    end


    test "adapter_thirdparty_id" do
      VCR.use_cassette("custom_webhook_v3_adapter_thirdparty_id") do
        @integration.adapter_incoming_request_params = @create_request
        assert_equal "12345", @integration.adapter_thirdparty_id
      end
    end

    test "adapter_process_create" do
      VCR.use_cassette("custom_webhook_v3_adapter_process_create") do
        @integration.adapter_incoming_request_params = @create_request

        true_alert = Alert.new(
          title: "My Website is DOWN",
          description: "My Website is DOWN because Connection timeout",
          urgency: "high",
          thirdparty_id: "12345",
          dedup_keys: ["xyz"],
          incident: true,
          incident_severity: "SEV-2",
          incident_message: "Please join the bridge",
          tags: [
            "monitor",
            "website"
          ],
          meta: {
            key1: "value1",
            key2: "value2"
          },
          additional_data: [
            AdditionalDatum.new(format: "link", label: "Monitor URL", value: "https://example.com"),
            AdditionalDatum.new(format: "datetime", label: "Triggered At", value: "1733126400")
          ]
        )

        assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
      end
    end
  end
end