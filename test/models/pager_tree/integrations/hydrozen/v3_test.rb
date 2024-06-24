require "test_helper"

module PagerTree::Integrations
  class Hydrozen::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:hydrozen_v3)

      @website_create_request = {
        monitor_id: "14",
        name: "Test",
        type: "website",
        target: "https://example.com",
        port: nil,
        is_ok: 0
      }.with_indifferent_access
      @website_resolve_request = @website_create_request.deep_dup
      @website_resolve_request["is_ok"] = 1

      @ping_create_request = {
        monitor_id: "14",
        name: "Test",
        type: "ping",
        target: "https://example.com",
        port: nil,
        is_ok: 0
      }.with_indifferent_access
      @ping_resolve_request = @ping_create_request.deep_dup
      @ping_resolve_request["is_ok"] = 1

      @port_create_request = {
        monitor_id: "12",
        name: "Port",
        type: "port",
        target: "199.59.2.8",
        port: ":1313",
        is_ok: 0
      }.with_indifferent_access
      @port_resolve_request = @port_create_request.deep_dup
      @port_resolve_request["is_ok"] = 1

      @heartbeat_create_request = {
        heartbeat_id: "1",
        name: "Payments Cron",
        type: "heartbeat",
        is_ok: 0
      }.with_indifferent_access
      @heartbeat_resolve_request = @heartbeat_create_request.deep_dup
      @heartbeat_resolve_request["is_ok"] = 1

      @domain_expiry_create_request = {
        domain_name_id: "1",
        name: "Textpro main site",
        target: "textpro.xyz",
        type: "domain-expiry",
        whois_end_datetime: "2023-01-01 11:28:45",
        timezone: "UTC"
      }.with_indifferent_access

      @ssl_expiry_create_request = {
        domain_name_id: "1",
        name: "Textpro main site",
        target: "textpro.xyz",
        type: "ssl-expiry",
        ssl_end_datetime: "2023-03-23 11:28:45",
        timezone: "UTC"
      }.with_indifferent_access

      @other_request = @website_create_request.deep_dup
      @other_request["type"] = "baaad"
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
      @integration.adapter_incoming_request_params = @website_create_request
      assert_equal :create, @integration.adapter_action

      @integration.adapter_incoming_request_params = @ping_create_request
      assert_equal :create, @integration.adapter_action

      @integration.adapter_incoming_request_params = @port_create_request
      assert_equal :create, @integration.adapter_action

      @integration.adapter_incoming_request_params = @heartbeat_create_request
      assert_equal :create, @integration.adapter_action

      @integration.adapter_incoming_request_params = @domain_expiry_create_request
      assert_equal :create, @integration.adapter_action

      @integration.adapter_incoming_request_params = @ssl_expiry_create_request
      assert_equal :create, @integration.adapter_action

      @integration.adapter_incoming_request_params = @website_resolve_request
      assert_equal :resolve, @integration.adapter_action

      @integration.adapter_incoming_request_params = @ping_resolve_request
      assert_equal :resolve, @integration.adapter_action

      @integration.adapter_incoming_request_params = @port_resolve_request
      assert_equal :resolve, @integration.adapter_action

      @integration.adapter_incoming_request_params = @heartbeat_resolve_request
      assert_equal :resolve, @integration.adapter_action

      @integration.adapter_incoming_request_params = @other_request
      assert_equal :other, @integration.adapter_action
    end

    test "adapter_thirdparty_id" do
      @integration.adapter_incoming_request_params = @website_create_request
      assert_equal "website-14", @integration.adapter_thirdparty_id

      @integration.adapter_incoming_request_params = @ping_create_request
      assert_equal "ping-14", @integration.adapter_thirdparty_id

      @integration.adapter_incoming_request_params = @port_create_request
      assert_equal "port-12", @integration.adapter_thirdparty_id

      @integration.adapter_incoming_request_params = @heartbeat_create_request
      assert_equal "heartbeat-1", @integration.adapter_thirdparty_id

      @integration.adapter_incoming_request_params = @domain_expiry_create_request
      assert_equal "domain-expiry-1", @integration.adapter_thirdparty_id

      @integration.adapter_incoming_request_params = @ssl_expiry_create_request
      assert_equal "ssl-expiry-1", @integration.adapter_thirdparty_id
    end

    test "adapter_process_create_website" do
      @integration.adapter_incoming_request_params = @website_create_request

      true_alert = Alert.new(
        title: "Website monitor Test is DOWN",
        description: "Website monitor Test (https://example.com) is DOWN",
        urgency: nil,
        thirdparty_id: "website-14",
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "URL", value: nil),
          AdditionalDatum.new(format: "text", label: "Name", value: "Test"),
          AdditionalDatum.new(format: "text", label: "Type", value: "website"),
          AdditionalDatum.new(format: "link", label: "Target", value: "https://example.com"),
          AdditionalDatum.new(format: "text", label: "port", value: nil)
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    test "adapter_process_create_ping" do
      @integration.adapter_incoming_request_params = @ping_create_request

      true_alert = Alert.new(
        title: "Ping monitor Test is DOWN",
        description: "Ping monitor Test (https://example.com) is DOWN",
        urgency: nil,
        thirdparty_id: "ping-14",
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "URL", value: nil),
          AdditionalDatum.new(format: "text", label: "Name", value: "Test"),
          AdditionalDatum.new(format: "text", label: "Type", value: "ping"),
          AdditionalDatum.new(format: "link", label: "Target", value: "https://example.com"),
          AdditionalDatum.new(format: "text", label: "port", value: nil)
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    test "adapter_process_create_port" do
      @integration.adapter_incoming_request_params = @port_create_request

      true_alert = Alert.new(
        title: "Port monitor Port is DOWN",
        description: "Port monitor Port (199.59.2.8) is DOWN",
        urgency: nil,
        thirdparty_id: "port-12",
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "URL", value: nil),
          AdditionalDatum.new(format: "text", label: "Name", value: "Port"),
          AdditionalDatum.new(format: "text", label: "Type", value: "port"),
          AdditionalDatum.new(format: "link", label: "Target", value: "199.59.2.8"),
          AdditionalDatum.new(format: "text", label: "port", value: ":1313")
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    test "adapter_process_create_hearbeat" do
      @integration.adapter_incoming_request_params = @heartbeat_create_request

      true_alert = Alert.new(
        title: "Heartbeat monitor Payments Cron has not checked in",
        description: "Heartbeat monitor Payments Cron has not checked in",
        urgency: nil,
        thirdparty_id: "heartbeat-1",
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "URL", value: nil),
          AdditionalDatum.new(format: "text", label: "Name", value: "Payments Cron"),
          AdditionalDatum.new(format: "text", label: "Type", value: "heartbeat")
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    test "adapter_process_create_domain_expiry" do
      @integration.adapter_incoming_request_params = @domain_expiry_create_request

      true_alert = Alert.new(
        title: "Domain monitor Textpro main site is expiring soon",
        description: "Domain monitor Textpro main site (textpro.xyz) is expiring soon (2023-01-01 11:28:45 UTC)",
        urgency: nil,
        thirdparty_id: "domain-expiry-1",
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "URL", value: nil),
          AdditionalDatum.new(format: "text", label: "Name", value: "Textpro main site"),
          AdditionalDatum.new(format: "text", label: "Type", value: "domain-expiry"),
          AdditionalDatum.new(format: "link", label: "Target", value: "textpro.xyz"),
          AdditionalDatum.new(format: "text", label: "WHOIS End DateTime", value: "2023-01-01 11:28:45 UTC")
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    test "adapter_process_create_ssl_expiry" do
      @integration.adapter_incoming_request_params = @ssl_expiry_create_request

      true_alert = Alert.new(
        title: "SSL Certificate monitor Textpro main site is expiring soon",
        description: "SSL Certificate monitor Textpro main site (textpro.xyz) is expiring soon (2023-03-23 11:28:45 UTC)",
        urgency: nil,
        thirdparty_id: "ssl-expiry-1",
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "URL", value: nil),
          AdditionalDatum.new(format: "text", label: "Name", value: "Textpro main site"),
          AdditionalDatum.new(format: "text", label: "Type", value: "ssl-expiry"),
          AdditionalDatum.new(format: "link", label: "Target", value: "textpro.xyz"),
          AdditionalDatum.new(format: "text", label: "SSL End DateTime", value: "2023-03-23 11:28:45 UTC")
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
