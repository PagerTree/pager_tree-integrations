require "test_helper"

module PagerTree::Integrations
  class Auvik::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:auvik_v3)

      # TODO: Write some requests to test the integration
      @create_request = {
        entityId: nil,
        subject: "You have a new alert!",
        alertStatusString: "Triggered",
        alertId: "NzA4MjA3MTIwMjU2OTMwNTU3LDcyMzQyODI2NzAyMDA5NjIzNw==",
        alertName: "PagerTree Title",
        entityName: "Auvik collector",
        companyName: "Jones, Stienman and Tweed",
        entityType: nil,
        date: "2021-06-29T13:46:51.998Z",
        link: "https://jsattree.us2.my.auvik.com/alert/723428267020096237/summary",
        alertStatus: 0,
        correlationId: "NzA4MjA3MTIwMjU2OTMwNTU3LDcyMzQyODI2NzAyMDA5NjIzNw==",
        alertDescription: "PagerTree Description",
        alertSeverityString: "Emergency",
        alertSeverity: 1,
        companyId: "708207120256930557"
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:alertStatus] = 1

      @other_request = @create_request.deep_dup
      @other_request[:alertStatus] = 20
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
      assert_equal @create_request[:correlationId], @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      # TODO: Check tthe entire transform
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request[:alertName],
        description: @create_request[:alertDescription],
        urgency: "critical",
        thirdparty_id: @create_request[:correlationId],
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "URL", value: @create_request[:link]),
          AdditionalDatum.new(format: "text", label: "Alert Severity", value: @create_request[:alertSeverityString]),
          AdditionalDatum.new(format: "text", label: "Correlation ID", value: @create_request[:correlationId]),
          AdditionalDatum.new(format: "text", label: "Alert ID", value: @create_request[:alertId]),
          AdditionalDatum.new(format: "text", label: "Entity ID", value: @create_request[:entityId]),
          AdditionalDatum.new(format: "text", label: "Entity Name", value: @create_request[:entityName]),
          AdditionalDatum.new(format: "text", label: "Entity Type", value: @create_request[:entityType]),
          AdditionalDatum.new(format: "text", label: "Entity ID", value: @create_request[:entityId]),
          AdditionalDatum.new(format: "text", label: "Company Name", value: @create_request[:companyName]),
          AdditionalDatum.new(format: "datetime", label: "Date", value: @create_request[:date])
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
