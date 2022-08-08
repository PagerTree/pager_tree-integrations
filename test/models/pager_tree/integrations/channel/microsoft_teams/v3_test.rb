require "test_helper"

module PagerTree::Integrations
  class Channel::MicrosoftTeams::V3Test < ActiveSupport::TestCase
    include Integrateable
    include ActiveJob::TestHelper

    setup do
      @integration = pager_tree_integrations_integrations(:channel_microsoft_teams_v3)

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

      @alert.created_at = @alert.created_at.to_datetime
      @alert.updated_at = @alert.updated_at.to_datetime

      @webhook_url = "https://webhook.example.com"

      @data = {
        event_name: :alert_acknowledged,
        item: @alert,
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

      @expected_payload = {
        "@type": "MessageCard",
        "@context": "http://schema.org/extensions",
        themeColor: "#fb8c00",
        summary: "Alert ##{@alert.tiny_id} #{@alert.title}",
        sections: [{
          activityTitle: "Alert ##{@alert.tiny_id} #{@alert.title}",
          activitySubtitle: nil,
          facts: [
            {
              name: "Status",
              value: @alert.status.upcase
            },
            {
              name: "Urgency",
              value: @alert.urgency.upcase
            },
            {
              name: "Created",
              value: @alert.created_at.utc
            },
            {
              name: "Source",
              value: @alert.source&.name
            },
            {
              name: "Destinations",
              value: @alert.alert_destinations.map { |d| d.destination.name }.join(", ")
            },
            {
              name: "User",
              value: nil
            }
          ],
          markdown: true
        }],
        potentialAction: [
          {
            "@context": "http://schema.org",
            "@type": "ViewAction",
            name: "View in PagerTree",
            target: [
              nil
            ]
          }
        ]
      }
    end

    test "sanity" do
      assert_not @integration.adapter_supports_incoming?
      assert @integration.adapter_incoming_can_defer?
      assert @integration.adapter_supports_outgoing?
      assert_not @integration.adapter_show_alerts?
      assert @integration.adapter_show_logs?
      assert @integration.adapter_show_outgoing_webhook_delivery?
    end

    test "outgoing_interest" do
      assert_not @integration.option_alert_open
      assert_not @integration.adapter_outgoing_interest?(:alert_open)
      @integration.option_alert_open = true
      assert @integration.adapter_outgoing_interest?(:alert_open)
    end

    test "can_process_outgoing" do
      assert_no_performed_jobs

      @integration.adapter_outgoing_event = OutgoingEvent.new(**@data)
      outgoing_webhook_delivery = @integration.adapter_process_outgoing

      assert_enqueued_jobs 1

      assert_equal @integration.option_incoming_webhook_url, outgoing_webhook_delivery.url
      assert_equal :queued.to_s, outgoing_webhook_delivery.status
      assert_equal @expected_payload.to_json, outgoing_webhook_delivery.body.to_json
    end

    test "respects outgoing rules data" do
      assert_no_performed_jobs

      @data[:outgoing_rules_data] = {
        webhook_url: @webhook_url,
        extra: true
      }.with_indifferent_access

      @integration.adapter_outgoing_event = OutgoingEvent.new(**@data)
      outgoing_webhook_delivery = @integration.adapter_process_outgoing

      assert_enqueued_jobs 1

      assert_equal @webhook_url, outgoing_webhook_delivery.url
      assert_equal :queued.to_s, outgoing_webhook_delivery.status

      @expected_payload[:extra] = true

      assert_equal @expected_payload.to_json, outgoing_webhook_delivery.body.to_json
    end
  end
end
