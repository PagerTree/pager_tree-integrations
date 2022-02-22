require "test_helper"

module PagerTree::Integrations
  class IntegrationTest < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = Integration.new
    end

    test "sanity" do
      assert_nil @integration.option_title_template
      assert_not @integration.option_title_template_enabled
      assert_nil @integration.option_description_template
      assert_not @integration.option_description_template_enabled
    end

    test "defaults" do
      assert_not @integration.adapter_supports_incoming?
      assert @integration.adapter_incoming_can_defer?
      assert @integration.adapter_thirdparty_id
      assert_equal :other, @integration.adapter_action
      assert_nil @integration.adapter_process_create
      assert_not @integration.adapter_supports_outgoing?
      assert_not @integration.adapter_outgoing_interest?("foo")

      assert_not @integration.adapter_show_alerts?
      assert @integration.adapter_show_logs?
      assert_not @integration.adapter_show_outgoing_webhook_delivery?

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

    test "attributes" do
      assert @integration.respond_to?(:adapter_controller)
      assert @integration.respond_to?(:adapter_incoming_request_params)
      assert @integration.respond_to?(:adapter_incoming_deferred_request)
      assert @integration.respond_to?(:adapter_alert)
      assert @integration.respond_to?(:adapter_outgoing_event)
    end
  end
end
