require "test_helper"

module PagerTree::Integrations
  class Pulsetic::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:pulsetic_v3)

      @create_request = {
        alert_type: "monitor_offline",
        monitor: {
          id: 123456,
          url: "https://statuscode.app/200"
        }
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:alert_type] = "monitor_online"

      @certificate_request = @create_request.deep_dup
      @certificate_request[:alert_type] = "certificate_expires_soon"
      @certificate_request[:days_left] = 5

      @other_request = @create_request.deep_dup
      @other_request[:alert_type] = "baaad"
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

      @integration.adapter_incoming_request_params = @certificate_request
      assert_equal :create, @integration.adapter_action

      @integration.adapter_incoming_request_params = @other_request
      assert_equal :other, @integration.adapter_action
    end

    test "adapter_thirdparty_id" do
      @integration.adapter_incoming_request_params = @create_request
      assert_equal "123456_monitor", @integration.adapter_thirdparty_id

      @integration.adapter_incoming_request_params = @certificate_request
      assert_equal "123456_certificate", @integration.adapter_thirdparty_id
    end

    test "adapter_process_create_monitor" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: "https://statuscode.app/200 OFFLINE",
        urgency: nil,
        thirdparty_id: "123456_monitor",
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Monitor", value: "https://app.pulsetic.com/monitors/123456/overview"),
          AdditionalDatum.new(format: "link", label: "URL", value: "https://statuscode.app/200")
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    test "adapter_process_create_certificate" do
      @integration.adapter_incoming_request_params = @certificate_request

      true_alert = Alert.new(
        title: "https://statuscode.app/200 CERTIFICATE EXPIRES SOON",
        urgency: nil,
        thirdparty_id: "123456_certificate",
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Monitor", value: "https://app.pulsetic.com/monitors/123456/overview"),
          AdditionalDatum.new(format: "link", label: "URL", value: "https://statuscode.app/200")
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
