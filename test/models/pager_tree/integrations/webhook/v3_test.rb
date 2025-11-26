require "test_helper"

module PagerTree::Integrations
  class Webhook::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:webhook_v3)

      @create_request = {
        event_type: "create",
        Id: "example-id-123",
        Title: "Example Incident Title",
        Description: "Example Incident Description",
        Urgency: "critical",
        Tags: [
          "a",
          "b",
          "c",
          "c"
        ],
        Meta: {
          incident: true,
          incident_severity: "sev-1",
          incident_message: "Please join conference bridge 1-800-123-4567",
          kube_pod_name: "example-pod-name"
        },
        dedup_keys: ["group_my_whole_account"]
      }.with_indifferent_access

      @acknowledge_request = @create_request.deep_dup
      @acknowledge_request[:event_type] = "acknowledge"

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

      @integration.adapter_incoming_request_params = @acknowledge_request
      assert_equal :acknowledge, @integration.adapter_action

      @integration.adapter_incoming_request_params = @resolve_request
      assert_equal :resolve, @integration.adapter_action

      @integration.adapter_incoming_request_params = @other_request
      assert_equal :other, @integration.adapter_action
    end

    test "adapter_thirdparty_id" do
      @integration.adapter_incoming_request_params = @create_request
      assert_equal @create_request.dig(:Id), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.dig(:Title),
        description: @create_request.dig(:Description),
        urgency: @create_request.dig(:Urgency).downcase,
        thirdparty_id: @create_request.dig(:Id),
        dedup_keys: @create_request.dig(:dedup_keys),
        incident: !!@create_request.dig(:Meta).dig(:incident),
        incident_severity: @create_request.dig(:Meta).dig(:incident_severity).upcase,
        incident_message: @create_request.dig(:Meta).dig(:incident_message),
        tags: @create_request.dig(:Tags).uniq,
        meta: @create_request.dig(:Meta).except(:incident, :incident_severity, :incident_message)
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json

      # TEST THE ADDITIONAL DATUM OPTION
      @integration.option_capture_additional_data = true
      @extra_key_request = @create_request.deep_dup
      @extra_key_request[:joe] = "bob"
      @integration.adapter_incoming_request_params = @extra_key_request

      true_alert = Alert.new(
        title: @create_request.dig(:Title),
        description: @create_request.dig(:Description),
        urgency: @create_request.dig(:Urgency).downcase,
        thirdparty_id: @create_request.dig(:Id),
        dedup_keys: @create_request.dig(:dedup_keys),
        incident: !!@create_request.dig(:Meta).dig(:incident),
        incident_severity: @create_request.dig(:Meta).dig(:incident_severity).upcase,
        incident_message: @create_request.dig(:Meta).dig(:incident_message),
        tags: @create_request.dig(:Tags).uniq,
        meta: @create_request.dig(:Meta).except(:incident, :incident_severity, :incident_message),
        additional_data: [
          AdditionalDatum.new(format: "text", label: "joe", value: "bob")
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    test "blocking_incoming" do
      @blocked_request = @create_request.deep_dup
      @integration.option_token = "abc123"
      assert @integration.adapter_should_block_incoming?(OpenStruct.new({headers: {"pagertree-token" => ""}}))
      assert_not @integration.adapter_should_block_incoming?(OpenStruct.new({headers: {"pagertree-token" => "abc123"}}))
    end

    test "wrapper_key" do
      @wrapped_create_request = {
        jkl: @create_request
      }.with_indifferent_access

      @wrapped_acknowledge_request = {
        jkl: @acknowledge_request
      }.with_indifferent_access

      @wrapped_resolve_request = {
        jkl: @resolve_request
      }.with_indifferent_access

      @wrapped_other_request = {
        jkl: @other_request
      }.with_indifferent_access

      @integration.option_wrapper_key = "jkl"

      @integration.adapter_incoming_request_params = @wrapped_create_request
      assert_equal :create, @integration.adapter_action

      @integration.adapter_incoming_request_params = @wrapped_acknowledge_request
      assert_equal :acknowledge, @integration.adapter_action

      @integration.adapter_incoming_request_params = @wrapped_resolve_request
      assert_equal :resolve, @integration.adapter_action

      @integration.adapter_incoming_request_params = @wrapped_other_request
      assert_equal :other, @integration.adapter_action
    end

    test "wrapper_key_jmespath" do
      @wrapped_create_request = {
        abc: {
          jkl: @create_request
        }
      }.with_indifferent_access

      @wrapped_acknowledge_request = {
        abc: {
          jkl: @acknowledge_request
        }
      }.with_indifferent_access

      @wrapped_resolve_request = {
        abc: {
          jkl: @resolve_request
        }
      }.with_indifferent_access

      @wrapped_other_request = {
        abc: {
          jkl: @other_request
        }
      }.with_indifferent_access

      @integration.option_wrapper_key = "abc.jkl"

      @integration.adapter_incoming_request_params = @wrapped_create_request
      assert_equal :create, @integration.adapter_action

      @integration.adapter_incoming_request_params = @wrapped_acknowledge_request
      assert_equal :acknowledge, @integration.adapter_action

      @integration.adapter_incoming_request_params = @wrapped_resolve_request
      assert_equal :resolve, @integration.adapter_action

      @integration.adapter_incoming_request_params = @wrapped_other_request
      assert_equal :other, @integration.adapter_action
    end

    test "wrapper_key_invalid_path" do
      @integration.option_wrapper_key = "nonexistent.path"
      @integration.adapter_incoming_request_params = @create_request
      # Should gracefully handle missing path
      assert_equal :create, @integration.adapter_action
    end

    test "wrapper_key_non_hash_value" do
      @integration.option_wrapper_key = "array_key"
      @integration.adapter_incoming_request_params = {array_key: ["not", "a", "hash"]}.with_indifferent_access
      # Should fall back to original params or handle gracefully
      assert_equal :other, @integration.adapter_action
    end
  end
end
