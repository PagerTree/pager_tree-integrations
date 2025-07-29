require "test_helper"

module PagerTree::Integrations
  class Dynatrace::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:dynatrace_v3)

      @create_request = {
        ImpactedEntities: [
          {type: "HOST", name: "MyHost1", entity: "HOST-XXXXXXXXXXXXX"},
          {type: "SERVICE", name: "MyService1", entity: "SERVICE-XXXXXXXXXXXXX"}
        ],
        ImpactedEntity: "MyHost1, MyService1",
        PID: "99999",
        ProblemDetailsHTML: "<h1>Dynatrace problem notification test run details</h1>",
        ProblemDetailsJSON: {ID: "99999"},
        ProblemID: "999",
        ProblemImpact: "INFRASTRUCTURE",
        ProblemTitle: "Dynatrace problem notification test run",
        "Problem URL": "https://example.com",
        State: "OPEN",
        Tags: "testtag1, testtag2"
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request["State"] = "RESOLVED"

      @other_request = @create_request.deep_dup
      @other_request["State"] = "baaad"
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
      assert_equal @create_request["ProblemID"], @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request["ProblemTitle"],
        description: @create_request["ProblemDetailsHTML"],
        urgency: nil,
        thirdparty_id: @create_request["ProblemID"],
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "URL", value: @create_request.dig("ProblemURL")),
          AdditionalDatum.new(format: "text", label: "Impacted Entity", value: @create_request.dig("ImpactedEntity")),
          AdditionalDatum.new(format: "text", label: "Problem Impact", value: @create_request.dig("ProblemImpact")),
          AdditionalDatum.new(format: "text", label: "Problem Severity", value: @create_request.dig("ProblemSeverity"))
        ],
        tags: @create_request["Tags"].split(",").map(&:strip).uniq.compact
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
