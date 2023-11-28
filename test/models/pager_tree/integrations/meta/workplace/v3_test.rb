require "test_helper"

module PagerTree::Integrations
  class Meta::Workplace::V3Test < ActiveSupport::TestCase
    include Integrateable
    include ActiveJob::TestHelper

    setup do
      @integration = pager_tree_integrations_integrations(:meta_workplace_v3)

      @alert = JSON.parse({
        id: "01G9ZET2HZSTA9B0YDAB9G7XPZ",
        account_id: "01G9ZDGQ0NYAF6E1M3C6FAYDV5",
        prefix_id: "alt_K22OuvPYNmCyvJ",
        tiny_id: 22,
        meta: {},
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

      @expected_payload = nil
    end

    def expected_message_url(group_id, message)
      "https://graph.facebook.com/#{group_id}/feed?message=#{CGI.escape(message)}&formatting=MARKDOWN"
    end

    def expected_comment_url(post_id, message)
      "https://graph.facebook.com/#{post_id}/comments?message=#{CGI.escape(message)}"
    end

    test "sanity" do
      assert_not @integration.adapter_supports_incoming?
      assert_not @integration.adapter_incoming_can_defer?
      assert @integration.adapter_supports_outgoing?
      assert_not @integration.adapter_show_alerts?
      assert @integration.adapter_show_logs?
      assert @integration.adapter_show_outgoing_webhook_delivery?
    end

    test "outgoing_interest" do
      assert @integration.option_outgoing_enabled
      assert_not @integration.adapter_outgoing_interest?(:alert_open)
      assert_not @integration.adapter_outgoing_interest?(:alert_timeout)
      assert @integration.adapter_outgoing_interest?(:alert_created)
      assert @integration.adapter_outgoing_interest?(:alert_acknowledged)
      assert @integration.adapter_outgoing_interest?(:alert_rejected)
      assert @integration.adapter_outgoing_interest?(:alert_resolved)
      assert @integration.adapter_outgoing_interest?(:alert_dropped)
      assert @integration.adapter_outgoing_interest?(:alert_handoff)
      assert @integration.adapter_outgoing_interest?(:comment_created)
    end

    test "can_process_outgoing_message" do
      data = {
        event_name: :alert_created,
        alert: @alert,
        changes: [{
          before: nil,
          after: @alert.as_json
        }],
        outgoing_rules_data: {}
      }

      assert_no_performed_jobs

      @integration.adapter_outgoing_event = OutgoingEvent.new(**data)
      outgoing_webhook_delivery = @integration.adapter_process_outgoing

      assert_enqueued_jobs 1

      assert_equal expected_message_url(@integration.option_group_id, "[Alert ##{@alert.tiny_id}](#{Rails.application.routes.url_helpers.try(:alert_url, @alert, script_name: "/#{@alert.account_id}")}) #{@alert.title}"), outgoing_webhook_delivery.url
      assert_equal :queued.to_s, outgoing_webhook_delivery.status
      assert_equal @expected_payload.to_json, outgoing_webhook_delivery.body.to_json
    end

    test "can_process_outgoing_comment" do
      @alert.meta["meta_workplace_post_id"] = "1234"
      data = {
        event_name: :alert_resolved,
        alert: @alert,
        changes: [{
          before: nil,
          after: @alert.as_json
        }],
        outgoing_rules_data: {}
      }

      assert_no_performed_jobs

      @integration.adapter_outgoing_event = OutgoingEvent.new(**data)
      outgoing_webhook_delivery = @integration.adapter_process_outgoing

      assert_enqueued_jobs 1

      assert_equal expected_comment_url(@alert.meta["meta_workplace_post_id"], "Resolved"), outgoing_webhook_delivery.url
      assert_equal :queued.to_s, outgoing_webhook_delivery.status
      assert_equal @expected_payload.to_json, outgoing_webhook_delivery.body.to_json
    end
  end
end
