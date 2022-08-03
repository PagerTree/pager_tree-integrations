require "test_helper"

module PagerTree::Integrations
  class Jotform::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:jotform_v3)

      @create_request = {
        formID: "form_123",
        formTitle: "Insurance Claim",
        submissionID: "submission_456"
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
      @integration.adapter_incoming_request_params = @create_request
      assert_equal @create_request.dig("submissionID"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: [@create_request.dig("formTitle"), @create_request.dig("submissionID")].join(" "),
        urgency: nil,
        thirdparty_id: @create_request.dig("submissionID"),
        dedup_keys: [@create_request.dig("submissionID")],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Submission URL", value: "https://www.jotform.com/submission/#{@create_request.dig("submissionID")}")
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
