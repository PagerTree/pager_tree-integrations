require "test_helper"

module PagerTree::Integrations
  class Freshdesk::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:freshdesk_v3)

      @create_request = {
        freshdesk_webhook: {
          ticket_id: "123",
          ticket_subject: "Ticket Subject",
          ticket_description: "Ticket Description",
          ticket_priority: 1,
          ticket_status: 2,
          ticket_url: "https://desk.freshdesk.com/ticket/123",
          ticket_due_by_time: "2022-05-23T08:18:26-05:00",
          ticket_source: "Customer",
          ticket_requester_name: "Joe Bob",
          ticket_requester_email: "joe.bob@example.com",
          ticket_requester_phone: nil,
          ticket_company_name: "Acme Corp"
        }
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:freshdesk_webhook][:ticket_status] = "Resolved"

      @other_request = @create_request.deep_dup
      @other_request[:freshdesk_webhook][:ticket_status] = "baaad"
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
      assert_equal @create_request[:freshdesk_webhook][:ticket_id], @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request[:freshdesk_webhook][:ticket_subject],
        description: @create_request[:freshdesk_webhook][:ticket_description],
        urgency: :low,
        thirdparty_id: @create_request[:freshdesk_webhook][:ticket_id],
        dedup_keys: [@create_request[:freshdesk_webhook][:ticket_id]],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Ticket URL", value: @create_request[:freshdesk_webhook].dig("ticket_url")),
          AdditionalDatum.new(format: "datetime", label: "Due By", value: @create_request[:freshdesk_webhook].dig("ticket_due_by_time")),
          AdditionalDatum.new(format: "text", label: "Source", value: @create_request[:freshdesk_webhook].dig("ticket_source")),
          AdditionalDatum.new(format: "text", label: "Requester Name", value: @create_request[:freshdesk_webhook].dig("ticket_requester_name")),
          AdditionalDatum.new(format: "text", label: "Requester Email", value: @create_request[:freshdesk_webhook].dig("ticket_requester_email")),
          AdditionalDatum.new(format: "text", label: "Requester Phone", value: @create_request[:freshdesk_webhook].dig("ticket_requester_phone")),
          AdditionalDatum.new(format: "text", label: "Company", value: @create_request[:freshdesk_webhook].dig("ticket_company_name"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
