require "test_helper"

module PagerTree::Integrations
  class StatusGator::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:status_gator_v3)

      @down_request = {
        service: {
          id: "abcdefghijkl",
          name: "My Monitor",
          slug: "0123456789abc12",
          status_page_url: "123.456.789.01",
          icon_url: "https://favicons.statusgator.com/0123456789abc12.png",
          landing_page_url: "https://statusgator.com/services/0123456789abc12"
        },
        monitor: {
          id: "8lJSR0I7fE",
          type: "PingMonitor",
          display_name: "My Monitor",
          description: "",
          icon_url: "https://favicons.statusgator.com/0123456789abc12.png",
          host: "123.456.789.01"
        },
        board: {
          id: "AbPas1igzR",
          name: "PagerTree LLC"
        },
        type: "StatusChange",
        recorded_at: "2025-11-21T20:28:33Z",
        status: "down",
        previous_status: "up",
        message: "Test message for PagerTree LLC",
        details: "If the service published incident details they'd be listed here. This might contain a more detailed message about the outage and the time to resolution."
      }.with_indifferent_access

      @warning_request = {
        service: {
          id: "abcdefghijkl",
          name: "My Monitor",
          slug: "0123456789abc12",
          status_page_url: "123.456.789.01",
          icon_url: "https://favicons.statusgator.com/0123456789abc12.png",
          landing_page_url: "https://statusgator.com/services/0123456789abc12"
        },
        monitor: {
          id: "8lJSR0I7fE",
          type: "PingMonitor",
          display_name: "My Monitor",
          description: "",
          icon_url: "https://favicons.statusgator.com/0123456789abc12.png",
          host: "123.456.789.01"
        },
        board: {
          id: "AbPas1igzR",
          name: "PagerTree LLC"
        },
        type: "StatusChange",
        recorded_at: "2025-11-21T20:29:16Z",
        status: "warn",
        previous_status: "up",
        message: "Test message for PagerTree LLC",
        details: "If the service published incident details they'd be listed here. This might contain a more detailed message about the outage and the time to resolution."
      }.with_indifferent_access

      @maintenance_request = {
        service: {
          id: "abcdefghijkl",
          name: "My Monitor",
          slug: "0123456789abc12",
          status_page_url: "123.456.789.01",
          icon_url: "https://favicons.statusgator.com/0123456789abc12.png",
          landing_page_url: "https://statusgator.com/services/0123456789abc12"
        },
        monitor: {
          id: "8lJSR0I7fE",
          type: "PingMonitor",
          display_name: "My Monitor",
          description: "",
          icon_url: "https://favicons.statusgator.com/0123456789abc12.png",
          host: "123.456.789.01"
        },
        board: {
          id: "AbPas1igzR",
          name: "PagerTree LLC"
        },
        type: "StatusChange",
        recorded_at: "2025-11-21T20:29:26Z",
        status: "maintenance",
        previous_status: "up",
        message: "Test message for PagerTree LLC",
        details: "If the service published incident details they'd be listed here. This might contain a more detailed message about the outage and the time to resolution."
      }.with_indifferent_access

      @up_request = {
        service: {
          id: "abcdefghijkl",
          name: "My Monitor",
          slug: "0123456789abc12",
          status_page_url: "123.456.789.01",
          icon_url: "https://favicons.statusgator.com/0123456789abc12.png",
          landing_page_url: "https://statusgator.com/services/0123456789abc12"
        },
        monitor: {
          id: "8lJSR0I7fE",
          type: "PingMonitor",
          display_name: "My Monitor",
          description: "",
          icon_url: "https://favicons.statusgator.com/0123456789abc12.png",
          host: "123.456.789.01"
        },
        board: {
          id: "AbPas1igzR",
          name: "PagerTree LLC"
        },
        type: "StatusChange",
        recorded_at: "2025-11-21T20:29:35Z",
        status: "up",
        previous_status: "down",
        message: "Test message for PagerTree LLC",
        details: "If the service published incident details they'd be listed here. This might contain a more detailed message about the outage and the time to resolution."
      }.with_indifferent_access

      @other_request = @down_request.dup
      @other_request[:status] = "unknown"

      @resolve_request = @up_request
      @create_request = @down_request
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

      @integration.adapter_incoming_request_params = @warning_request
      assert_not @integration.option_create_on_warn
      assert_equal :other, @integration.adapter_action
      @integration.option_create_on_warn = true
      assert @integration.option_create_on_warn
      assert_equal :create, @integration.adapter_action

      @integration.adapter_incoming_request_params = @maintenance_request
      assert_not @integration.option_create_on_maintenance
      assert_equal :other, @integration.adapter_action
      @integration.option_create_on_maintenance = true
      assert @integration.option_create_on_maintenance
      assert_equal :create, @integration.adapter_action
    end

    test "adapter_thirdparty_id" do
      @integration.adapter_incoming_request_params = @create_request
      assert_equal @create_request.dig("monitor", "id"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.dig("message"),
        description: @create_request.dig("details"),
        urgency: nil,
        thirdparty_id: @create_request.dig("monitor", "id"),
        additional_data: [
          AdditionalDatum.new(format: "text", label: "Monitor Name", value: @create_request.dig("monitor", "display_name")),
          AdditionalDatum.new(format: "datetime", label: "Recorded At", value: @create_request.dig("recorded_at"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
