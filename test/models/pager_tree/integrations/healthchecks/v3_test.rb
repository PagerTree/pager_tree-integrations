require "test_helper"

module PagerTree::Integrations
  class Healthchecks::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:healthchecks_v3)

      # https://healthchecks.io/docs/api/
      @create_request = {
        incident_key: "5398178f-6e2c-4a46-80ac-c083551f4beb",
        event_type: "trigger",
        tags: "",
        client_url: "http://192.241.216.208:8000",
        description: "my check is DOWN.\n\nLast ping was 2 minutes ago.",
        title: "my check is DOWN",
        client: "healthchecks.io"
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:event_type] = "resolve"

      @other_request = @create_request.deep_dup
      @other_request[:event_type] = "baaad"
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

      @integration.adapter_incoming_request_params = @resolve_request
      assert_equal :resolve, @integration.adapter_action

      @integration.adapter_incoming_request_params = @other_request
      assert_equal :other, @integration.adapter_action
    end

    test "adapter_thirdparty_id" do
      @integration.adapter_incoming_request_params = @create_request
      assert_equal @create_request[:incident_key], @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request[:title],
        description: @create_request[:description],
        urgency: nil,
        thirdparty_id: @create_request[:incident_key],
        dedup_keys: [@create_request[:incident_key]],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Client URL", value: @create_request.dig("client_url")),
          AdditionalDatum.new(format: "text", label: "Client", value: @create_request.dig("client"))
        ],
        tags: []
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
