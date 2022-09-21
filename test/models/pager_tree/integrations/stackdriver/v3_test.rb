require "test_helper"

module PagerTree::Integrations
  class Stackdriver::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:stackdriver_v3)

      @create_request = {
        incident: {
          condition: {
            conditionThreshold: {
              aggregations: [{
                alignmentPeriod: "300s",
                perSeriesAligner: "ALIGN_SUM"
              }, {
                alignmentPeriod: "300s",
                crossSeriesReducer: "REDUCE_SUM",
                perSeriesAligner: "ALIGN_SUM"
              }],
              comparison: "COMPARISON_LT",
              duration: "300s",
              filter: "resource.type = \"cloud_function\" AND resource.labels.function_name = \"webhook_health_endpoint\" AND metric.type = \"cloudfunctions.googleapis.com/function/execution_count\"",
              thresholdValue: 4,
              trigger: {
                count: 1
              }
            },
            displayName: "Cloud Function - Executions",
            name: "projects/exampleapp-hrd/alertPolicies/1234567890/conditions/1235467890"
          },
          condition_name: "Cloud Function - Executions",
          documentation: {
            content: "This alert means that the webhooks workflow is either not responding or broken in some way. The first thing to check is that the webhooks heartbeat job is running and that all the webhook-related services are up and running. Notify the #integrations-support channel if they have not been alerted already.",
            mime_type: "text/markdown"
          },
          ended_at: nil,
          incident_id: "0.ab1cdefgh2i",
          metadata: {
            system_labels: {},
            user_labels: {}
          },
          metric: {
            displayName: "Executions",
            labels: {},
            type: "cloudfunctions.googleapis.com/function/execution_count"
          },
          observed_value: "0.000",
          policy_name: "INTEG: Webhooks Health Check",
          resource: {
            labels: {
              function_name: "webhook_health_endpoint",
              project_id: "exampleapp-hrd"
            },
            type: "cloud_function"
          },
          resource_id: "",
          resource_name: "exampleapp-hrd Cloud Function labels {project_id=exampleapp-hrd, function_name=webhook_health_endpoint}",
          resource_type_display_name: "Cloud Function",
          scoping_project_id: "exampleapp-hrd",
          scoping_project_number: 720586683766,
          started_at: 1659643749,
          state: "open",
          summary: "Executions for exampleapp-hrd Cloud Function labels {project_id=exampleapp-hrd, function_name=webhook_health_endpoint} is below the threshold of 4.000 with a value of 0.000.",
          threshold_value: "4",
          url: "https://console.cloud.google.com/monitoring/alerting/incidents/0.ab1cdefgh2i?project=exampleapp-hrd"
        },
        version: "1.2"
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:incident][:state] = "closed"

      @other_request = @create_request.deep_dup
      @other_request[:incident][:state] = "baaad"
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
      assert_equal @create_request[:incident][:incident_id], @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request[:incident][:summary],
        urgency: nil,
        thirdparty_id: @create_request[:incident][:incident_id],
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Incident URL", value: @create_request.dig("incident", "url")),
          AdditionalDatum.new(format: "text", label: "Policy Name", value: @create_request.dig("incident", "policy_name")),
          AdditionalDatum.new(format: "text", label: "Condition Name", value: @create_request.dig("incident", "condition_name")),
          AdditionalDatum.new(format: "text", label: "Resource Name", value: @create_request.dig("incident", "resource_name"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
