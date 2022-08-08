require "test_helper"

module PagerTree::Integrations
  class OutgoingWebhook::V3Test < ActiveSupport::TestCase
    include Integrateable
    include ActiveJob::TestHelper

    setup do
      @integration = pager_tree_integrations_integrations(:outgoing_webhook_v3)
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
      assert @integration.adapter_outgoing_interest?(:alert_created)
      assert_not @integration.adapter_outgoing_interest?(:foo)
    end

    test "can_process_outgoing" do
      assert_no_performed_jobs

      data = {
        event_name: :alert_created,
        item: {
          foo: "bar"
        },
        changes: [{
          before: {
            foo: "baz"
          },
          after: {
            foo: "bar"
          }
        }]
      }
      expected_payload = {
        data: data[:item],
        type: "alert.created"
      }

      @integration.adapter_outgoing_event = OutgoingEvent.new(**data)
      outgoing_webhook_delivery = @integration.adapter_process_outgoing

      assert_enqueued_jobs 1

      assert_equal @integration.option_webhook_url, outgoing_webhook_delivery.url
      assert_equal :queued.to_s, outgoing_webhook_delivery.status
      assert_equal expected_payload.to_json, outgoing_webhook_delivery.body.to_json
    end
  end
end
