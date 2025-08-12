require "test_helper"

module PagerTree::Integrations
  class UptimeObserver::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:uptime_observer_v3)

      @create_request = {
        incident_url: "https://app.uptimeobserver.com/monitoring/incidents/123456",
        incident_id: 123456,
        title: "Incident Title",
        description: "Monitor 1 failed. Reason Socket Timeout",
        incident_status: "Active",
        monitor_id: 54321,
        monitor_name: "Monitor 1",
        monitor_url: "https://app.uptimeobserver.com/monitoring/monitor/123456"
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:incident_status] = "Resolved"

      @other_request = @create_request.deep_dup
      @other_request[:incident_status] = "unknown"
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
      assert_equal @create_request.dig(:incident_id), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.dig(:title),
        description: @create_request.dig(:description),
        urgency: nil,
        thirdparty_id: @create_request.dig(:incident_id),
        dedup_keys: [@create_request.dig(:incident_id)],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Incident URL", value: @create_request.dig(:incident_url)),
          AdditionalDatum.new(format: "link", label: "Monitor URL", value: @create_request.dig(:monitor_url))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
