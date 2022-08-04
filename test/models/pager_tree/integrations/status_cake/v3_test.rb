require "test_helper"

module PagerTree::Integrations
  class StatusCake::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:status_cake_v3)

      @create_request = {
        TestID: "1234567890",
        URL: "https://www.example.com/app",
        Token: "abc123",
        Method: "Website",
        Name: "https://www.example.com/app",
        StatusCode: "503",
        Status: "Down",
        Checkrate: "3600",
        Tags: ""
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:Status] = "Up"

      @other_request = @create_request.deep_dup
      @other_request[:Status] = "baaad"
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
      assert_equal @create_request.dig("URL"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: "#{@create_request.dig("Name")} is down",
        urgency: nil,
        thirdparty_id: @create_request.dig("URL"),
        dedup_keys: [@create_request.dig("URL")],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "URL", value: @create_request.dig("URL")),
          AdditionalDatum.new(format: "text", label: "Status Code", value: @create_request.dig("StatusCode")),
          AdditionalDatum.new(format: "text", label: "IP", value: @create_request.dig("IP")),
          AdditionalDatum.new(format: "text", label: "Check Rate", value: @create_request.dig("Check Rate"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
