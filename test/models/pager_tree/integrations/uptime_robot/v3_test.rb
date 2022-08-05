require "test_helper"

module PagerTree::Integrations
  class UptimeRobot::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:uptime_robot_v3)

      @create_request = {
        monitorID: "123456789",
        monitorURL: "https://prod.example.come",
        monitorFriendlyName: "example.come backend",
        alertType: "1",
        alertTypeFriendlyName: "Down",
        alertDetails: "HTTP 500 - Internal Server Error",
        monitorAlertContacts: "https://api.pagertree.com/integration/int_123456789/g",
        alertDateTime: "1659545625",
        alertID: "987654321"
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:alertTypeFriendlyName] = "Up"

      @other_request = @create_request.deep_dup
      @other_request[:alertTypeFriendlyName] = "baaad"
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
      assert_equal @create_request.dig("monitorID"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: "#{@create_request.dig("monitorFriendlyName")} is DOWN",
        description: "#{@create_request.dig("monitorFriendlyName")} is DOWN because #{@create_request.dig("alertDetails")}",
        urgency: nil,
        thirdparty_id: @create_request.dig("monitorID"),
        dedup_keys: [@create_request.dig("monitorID")],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Monitor URL", value: @create_request.dig("monitorURL")),
          AdditionalDatum.new(format: "datetime", label: "Triggered At", value: Time.at(@create_request.dig("alertDateTime").to_i).utc.to_datetime)
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    test "adapter_respects_groupSeconds_parameter" do
      @create_request[:groupSeconds] = "60"

      @integration.adapter_incoming_request_params = @create_request
      assert_equal :create, @integration.adapter_action

      integration_alert = @integration.adapter_process_create
      assert_equal 1659545580, integration_alert.thirdparty_id
    end
  end
end
