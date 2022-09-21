require "test_helper"

module PagerTree::Integrations
  class Uptime::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:uptime_v3)

      @create_request = {
        data: {
          service: {
            id: 764692,
            name: "SwiftCom - Concert Events",
            device_id: 422845,
            monitoring_service_type: "ICMP",
            is_paused: false,
            msp_address: "127.0.01",
            msp_version: 1,
            msp_interval: 5,
            msp_sensitivity: 4,
            msp_num_retries: 2,
            msp_url_scheme: "",
            msp_url_path: "",
            msp_port: nil,
            msp_protocol: "",
            msp_username: "",
            msp_proxy: "",
            msp_dns_server: "",
            msp_dns_record_type: "",
            msp_status_code: "",
            msp_send_string: "",
            msp_expect_string: "",
            msp_expect_string_type: "STRING",
            msp_encryption: "",
            msp_threshold: nil,
            msp_notes: "",
            msp_include_in_global_metrics: true,
            msp_use_ip_version: "",
            msp_uptime_sla: "0.9900",
            msp_response_time_sla: "1.200",
            monitoring_service_type_display: "ICMP(Ping)",
            display_name: "SwiftCom - Concert Events",
            short_name: "SwiftCom - Concert Events",
            tags: ["SwiftCom"]
          },
          account: {
            id: 123,
            name: "Acme Inc.",
            brand: "uptime",
            timezone: "America/New_York",
            site_url: "https://uptime.com"
          },
          integration: {
            id: 456,
            name: "PagerTree",
            module: "webhook",
            module_verbose_name: "Custom Postback URL (Webhook)",
            is_enabled: true,
            is_errored: false,
            is_test_supported: true,
            postback_url: "https://api.pagertree.com/integration/int_123456789",
            headers: "",
            use_legacy_payload: false
          },
          date: "2022-08-04T10:44:00.420Z",
          alert: {
            id: 789,
            created_at: "2022-08-04T10:44:00.420Z",
            state: "CRITICAL",
            output: "PING CRITICAL - Packet loss = 100%\n\nrta=1200.000000ms;600.000000;1200.000000;0.000000 pl=100%;30;60;0",
            short_output: "PING CRITICAL - Packet loss = 100%",
            is_up: false
          },
          global_alert_state: {
            id: 987,
            created_at: "2022-08-04T10:44:00.420Z",
            num_locations_down: 4,
            state_is_up: false,
            state_has_changed: true,
            ignored: false
          },
          device: {
            id: 654,
            name: "",
            address: "97.105.107.130",
            is_paused: false,
            display_name: "97.105.107.130"
          },
          locations: ["Canada", "US West", "US East", "Australia"],
          links: {
            alert_details: "https://uptime.com/accounts/em/300n?next=/alerting/alert-history/123456789",
            real_time_analysis: "https://uptime.com/accounts/em/300n?next=/devices/services/123456789/analysis"
          }
        },
        event: "alert_raised"
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:event] = "alert_cleared"

      @other_request = @create_request.deep_dup
      @other_request[:event] = "baaad"
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
      assert_equal @create_request.dig("data", "service", "id"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.dig("data", "service", "display_name"),
        description: @create_request.dig("data", "alert", "output"),
        urgency: nil,
        thirdparty_id: @create_request.dig("data", "service", "id"),
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "text", label: "Service Name", value: @create_request.dig("data", "service", "name")),
          AdditionalDatum.new(format: "text", label: "Service Address", value: @create_request.dig("data", "service", "msp_address"))
        ],
        tags: Array(@create_request.dig("data", "service", "tags")).compact_blank.uniq
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
