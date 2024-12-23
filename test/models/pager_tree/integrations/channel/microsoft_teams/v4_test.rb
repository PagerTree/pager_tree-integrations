require "test_helper"

module PagerTree::Integrations
  class Channel::MicrosoftTeams::V4Test < ActiveSupport::TestCase
    include Integrateable
    include ActiveJob::TestHelper

    setup do
      @integration = pager_tree_integrations_integrations(:channel_microsoft_teams_v4)

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

      @expected_payload = {
        type: "message",
        attachments: [
          {
            contentType: "application/vnd.microsoft.card.adaptive",
            contentUrl: nil,
            content: {
              type: "AdaptiveCard",
              body: [
                {
                  type: "Container",
                  backgroundImage: "https://pagertree.com/assets/img/icon/yellow-square.png",
                  items: [
                    {
                      type: "TextBlock",
                      size: "Large",
                      weight: "Bolder",
                      text: "Alert ##{@alert.tiny_id} #{@alert.title}"
                    },
                    {
                      type: "ColumnSet",
                      columns: [
                        {
                          type: "Column",
                          items: [
                            {
                              type: "TextBlock",
                              weight: "Bolder",
                              text: "Alert ##{@alert.tiny_id} #{@alert.title}",
                              wrap: true
                            },
                            {
                              type: "TextBlock",
                              spacing: "None",
                              text: "Created #{@alert.created_at.in_time_zone(@integration.option_time_zone).iso8601}",
                              wrap: true
                            }
                          ],
                          width: "stretch"
                        }
                      ]
                    }
                  ]
                },
                {
                  type: "Container",
                  items: [
                    {
                      type: "FactSet",
                      facts: [
                        {
                          title: "Status:",
                          value: @alert.status&.upcase
                        }, {
                          title: "Urgency:",
                          value: @alert.urgency&.upcase
                        }, {
                          title: "Source:",
                          value: @alert.source&.name
                        }, {
                          title: "Destinations:",
                          value: @alert.alert_destinations&.map { |d| d.destination.name }&.join(", ")
                        }, {
                          title: "User:",
                          value: @alert.alert_responders&.where(role: :incident_commander)&.includes(account_user: :user)&.first&.account_user&.name
                        }
                      ],
                      spacing: "None"
                    }
                  ],
                  spacing: "Medium"
                },
                {
                  type: "Container",
                  items: [
                    {
                      type: "TextBlock",
                      text: @alert.description&.try(:to_plain_text),
                      wrap: true,
                      separator: true,
                      maxLines: 24
                    },
                    {
                      type: "FactSet",
                      facts: @alert.additional_data&.map { |ad| {title: ad["label"], value: ad["value"]} } || [],
                      spacing: "Medium",
                      separator: true
                    }
                  ],
                  spacing: "Medium",
                  separator: true
                }
              ],
              actions: [
                {
                  type: "Action.OpenUrl",
                  title: "View",
                  url: Rails.application.routes.url_helpers.try(:alert_url, @alert, script_name: "/#{@alert.account_id}"),
                  style: "positive"
                }
              ],
              "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
              version: "1.2"
            }
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
