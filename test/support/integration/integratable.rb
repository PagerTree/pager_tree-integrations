module Integrateable
  extend ActiveSupport::Concern

  included do
    def test_responds_to_interface
      assert @integration.respond_to?(:adapter_supports_incoming?)
      assert @integration.respond_to?(:adapter_incoming_can_defer?)
      assert @integration.respond_to?(:adapter_thirdparty_id)
      assert @integration.respond_to?(:adapter_action)
      assert @integration.respond_to?(:adapter_process_create)
      assert @integration.respond_to?(:adapter_supports_outgoing?)
      assert @integration.respond_to?(:adapter_outgoing_interest?)
      assert @integration.respond_to?(:adapter_show_alerts?)
      assert @integration.respond_to?(:adapter_show_logs?)
      assert @integration.respond_to?(:adapter_show_outgoing_webhook_delivery?)

      assert @integration.respond_to?(:adapter_response_rate_limit)
      assert @integration.respond_to?(:adapter_response_disabled)
      assert @integration.respond_to?(:adapter_response_inactive_subscription)
      assert @integration.respond_to?(:adapter_response_upgrade)
      assert @integration.respond_to?(:adapter_response_maintenance_mode)
      assert @integration.respond_to?(:adapter_response_blocked)
      assert @integration.respond_to?(:adapter_response_deferred)
      assert @integration.respond_to?(:adapter_response_incoming)
      assert @integration.respond_to?(:cast_types)
    end
  end
end