require "test_helper"

module PagerTree::Integrations
  class AzureMonitor::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:azure_monitor_v3)

      @create_request = {
        schemaId: "azureMonitorCommonAlertSchema",
        data: {
          essentials: {
            alertId: "/subscriptions/<subscription ID>/providers/Microsoft.AlertsManagement/alerts/b9569717-bc32-442f-add5-83a997729330",
            alertRule: "WCUS-R2-Gen2",
            severity: "Sev3",
            signalType: "Metric",
            monitorCondition: "Fired",
            monitoringService: "Platform",
            alertTargetIDs: [
              "/subscriptions/<subscription ID>/resourcegroups/pipelinealertrg/providers/microsoft.compute/virtualmachines/wcus-r2-gen2"
            ],
            configurationItems: [
              "wcus-r2-gen2"
            ],
            originAlertId: "3f2d4487-b0fc-4125-8bd5-7ad17384221e_PipeLineAlertRG_microsoft.insights_metricAlerts_WCUS-R2-Gen2_-117781227",
            firedDateTime: "2019-03-22T13:58:24.3713213Z",
            resolvedDateTime: "2019-03-22T14:03:16.2246313Z",
            description: "",
            essentialsVersion: "1.0",
            alertContextVersion: "1.0"
          },
          alertContext: {
            properties: nil,
            conditionType: "SingleResourceMultipleMetricCriteria",
            condition: {
              windowSize: "PT5M",
              allOf: [
                {
                  metricName: "Percentage CPU",
                  metricNamespace: "Microsoft.Compute/virtualMachines",
                  operator: "GreaterThan",
                  threshold: "25",
                  timeAggregation: "Average",
                  dimensions: [
                    {
                      name: "ResourceId",
                      value: "3efad9dc-3d50-4eac-9c87-8b3fd6f97e4e"
                    }
                  ],
                  metricValue: 7.727
                }
              ]
            }
          }
        }
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:data][:essentials][:monitorCondition] = "Resolved"

      @other_request = @create_request.deep_dup
      @other_request[:data][:essentials][:monitorCondition] = "baaad"
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
      assert_equal @create_request[:data][:essentials][:alertId], @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      # TODO: Check tthe entire transform
      @integration.adapter_incoming_request_params = @create_request

      essentials = @create_request[:data][:essentials]
      true_alert = Alert.new(
        title: @create_request[:data][:essentials][:alertRule],
        description: @create_request[:data][:essentials][:description],
        urgency: "medium",
        thirdparty_id: @create_request[:data][:essentials][:alertId],
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "text", label: "Monitoring Service", value: essentials.dig("monitoringService")),
          AdditionalDatum.new(format: "text", label: "Alert Rule", value: essentials.dig("alertRule")),
          AdditionalDatum.new(format: "text", label: "Severity", value: essentials.dig("severity")),
          AdditionalDatum.new(format: "datetime", label: "Fired At", value: essentials.dig("firedDateTime"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
