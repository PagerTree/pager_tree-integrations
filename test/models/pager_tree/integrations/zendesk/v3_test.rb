require "test_helper"

module PagerTree::Integrations
  class Zendesk::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:zendesk_v3)

      @create_request = {
        event_type: "create",
        id: "5302",
        title: "Cannot connect to site through application",
        description: "----------------------------------------------\n\nJoe Bob, Aug 3, 2022, 3:52 PM\n\nWe acquired a new license and installed correctly.  We are now getting an error when trying to connect to the site through application\r\n\r\nMSI (s) (88:64) [15:41:03:238]: Product: Application Loader 0.1X -- Error 123. Could not write value  to key \\Software\\Classes\\CLSID\\{ABC123-ABCD-1234-EFGH-ABC123456}.  System error .  Verify that you have sufficient access to that key, or contact your support personnel.\r\n\r\nError 123. Could not write value  to key \\Software\\Classes\\CLSID\\{ABC123-ABCD-1234-EFGH-ABC123456}.  System error .  Verify that you have sufficient access to that key, or contact your support personnel.",
        ticket_type: "Incident",
        priority: "Normal",
        status: "New"
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
      assert_equal @create_request.dig("id"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.dig("title"),
        description: "<pre>#{@create_request.dig("description")}</pre>",
        urgency: "medium",
        thirdparty_id: @create_request.dig("id"),
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Zendesk Link", value: @create_request.dig("link")),
          AdditionalDatum.new(format: "text", label: "Priority", value: @create_request.dig("priority")),
          AdditionalDatum.new(format: "text", label: "Ticket Type", value: @create_request.dig("ticket_type")),
          AdditionalDatum.new(format: "text", label: "Via", value: @create_request.dig("via")),
          AdditionalDatum.new(format: "text", label: "Assignee Name", value: @create_request.dig("assignee_name"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
