require "test_helper"

module PagerTree::Integrations
  class Prtg::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:prtg_v3)

      @create_request = {
        sensorid: "sensor_123",
        status: "Down",
        name: "Image Processing",
        down: "",
        message: "1h 14m  (Newest File) is above the error limit of 1h in Newest File"
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:status] = "Down ended (now: Up)"

      @other_request = @create_request.deep_dup
      @other_request[:status] = "Down ended (now: Paused)"
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
      assert_equal @create_request.dig("sensorid"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: "Sensor #{@create_request.dig("sensorid")} #{@create_request.dig("sensor")} is DOWN",
        urgency: nil,
        thirdparty_id: @create_request.dig("sensorid"),
        dedup_keys: [],
        additional_data: @create_request.map do |key, value|
          AdditionalDatum.new(format: "text", label: key, value: value.to_s)
        end
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
