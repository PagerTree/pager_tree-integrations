require "test_helper"

module PagerTree::Integrations
  class Form::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:form_v3)

      @create_request = {
        name: "Joe Bob",
        email: "joe.bob@example.com",
        phone: "+15555555555",
        title: "Test title",
        description: "Test description",
        urgency: "low"
      }.with_indifferent_access
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
    end

    test "adapter_thirdparty_id" do
      # TODO: Check that the third party id comes back as expected
      @integration.adapter_incoming_request_params = @create_request
      assert thirdparty_id = @integration.adapter_thirdparty_id
      assert_equal @integration.adapter_thirdparty_id, thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request
      thirdparty_id = @integration.adapter_thirdparty_id

      true_alert = Alert.new(
        title: @create_request.dig("title"),
        description: @create_request.dig("description"),
        urgency: "low",
        thirdparty_id: thirdparty_id,
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "text", label: "Name", value: @create_request.dig("name")),
          AdditionalDatum.new(format: "email", label: "Email", value: @create_request.dig("email")),
          AdditionalDatum.new(format: "phone", label: "Phone", value: @create_request.dig("phone"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
