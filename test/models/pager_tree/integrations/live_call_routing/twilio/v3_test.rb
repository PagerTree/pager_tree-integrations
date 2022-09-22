require "test_helper"

module PagerTree::Integrations
  class LiveCallRouting::Twilio::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:live_call_routing_twilio_v3)
    end

    test "sanity" do
      assert @integration.adapter_supports_incoming?
      assert_not @integration.adapter_incoming_can_defer?
      assert @integration.adapter_supports_outgoing?
      assert @integration.adapter_will_route_alert?
      assert @integration.adapter_show_alerts?
      assert @integration.adapter_show_logs?
      assert_not @integration.adapter_show_outgoing_webhook_delivery?
    end

    test "validations" do
      @empty_integration = PagerTree::Integrations::LiveCallRouting::Twilio::V3.new
      assert_not @empty_integration.valid?

      @filled_integration = PagerTree::Integrations::LiveCallRouting::Twilio::V3.new(
        option_account_sid: "ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
        option_api_key: "SKXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
        option_api_secret: "secret"
      )
      assert @filled_integration.valid?
    end
  end
end
