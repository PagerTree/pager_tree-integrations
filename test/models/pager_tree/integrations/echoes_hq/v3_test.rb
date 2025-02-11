require "test_helper"

module PagerTree::Integrations
  class EchoesHq::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:echoes_hq_v3)

      @alert = JSON.parse({
        id: "01G9ZET2HZSTA9B0YDAB9G7XPZ",
        account_id: "01G9ZDGQ0NYAF6E1M3C6FAYDV5",
        prefix_id: "alt_K22OuvPYNmCyvJ",
        tiny_id: 22,
        source: {
          name: "Joe Bob"
        },
        title: "new alert",
        status: "acknowledged",
        urgency: "medium",
        created_at: "2022-08-08T19:27:20.127Z",
        updated_at: "2022-08-08T19:27:49.256Z",
        incident: false,
        incident_severity: "sev_1",
        incident_message: "",
        alert_destinations: [
          {
            destination: {
              name: "Team Bobcats"
            }
          }
        ]
      }.to_json, object_class: OpenStruct)

      @data = {
        event_name: :alert_acknowledged,
        alert: @alert,
        changes: [{
          before: {
            status: "open"
          },
          after: {
            foo: "ackowledged"
          }
        }],
        outgoing_rules_data: {}
      }

      @alert.created_at = @alert.created_at.to_datetime
      @alert.updated_at = @alert.updated_at.to_datetime
    end

    test "sanity" do
      assert_not @integration.adapter_supports_incoming?
      assert @integration.adapter_incoming_can_defer?
      assert @integration.adapter_supports_outgoing?
      assert_not @integration.adapter_show_alerts?
      assert @integration.adapter_show_logs?
      assert_not @integration.adapter_show_outgoing_webhook_delivery?
    end

    test "outgoing_interest" do
      assert @integration.adapter_outgoing_interest?(:alert_open)
      assert @integration.adapter_outgoing_interest?(:alert_acknowledged)
      assert @integration.adapter_outgoing_interest?(:alert_resolved)
      assert_not @integration.adapter_outgoing_interest?(:alert_dropped)
    end
  end
end
