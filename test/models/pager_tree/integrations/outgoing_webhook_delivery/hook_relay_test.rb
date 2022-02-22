require "test_helper"

module PagerTree::Integrations
  class OutgoingWebhookDelivery::HookRelayTest < ActiveSupport::TestCase
    setup do
    end

    test "test_deliver" do
      VCR.use_cassette("outgoing_webhook_delivery_hook_relay_test_deliver") do
        @outgoing_webhook_delivery = pager_tree_integrations_outgoing_webhook_deliveries(:hook_relay_queued)
        @outgoing_webhook_delivery.deliver
        assert_equal :sent.to_s, @outgoing_webhook_delivery.status
      end
    end

    test "test_delivery" do
      VCR.use_cassette("outgoing_webhook_delivery_hook_relay_test_delivery") do
        @outgoing_webhook_delivery = pager_tree_integrations_outgoing_webhook_deliveries(:hook_relay_sent)
        assert @outgoing_webhook_delivery.delivery.present?
        assert @outgoing_webhook_delivery.request.present?
        assert @outgoing_webhook_delivery.responses.present?
        assert_equal 1, @outgoing_webhook_delivery.responses.count
      end
    end
  end
end
