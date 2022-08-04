require "test_helper"

module PagerTree::Integrations
  class Prometheus::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:prometheus_v3)

      # https://prometheus.io/docs/alerting/latest/configuration/#webhook_config
      @create_request = {
        receiver: "pagertree",
        status: "firing",
        alerts: [{
          status: "firing",
          labels: {
            alertname: "ContainerRestarted",
            app_kubernetes_io_component: "kube-state-metrics",
            app_kubernetes_io_name: "testapp",
            container: "testapp-api-worker",
            instance: "testapp-kube-state-metrics.monitoring.svc:8080",
            job: "kube-state-metrics",
            k8s_app: "kube-state-metrics",
            namespace: "testapp-test",
            pod: "testapp-test-api-worker-deployment-1234567890-abcef",
            severity: "critical"
          },
          annotations: {
            summary: "Container testapp-api-worker of pod testapp-test-api-worker-deployment-1234567890-abcef has been restarted"
          },
          startsAt: "2022-08-04T09:01:58.1Z",
          endsAt: "0001-01-01T00:00:00Z",
          generatorURL: "http://127.0.0.1:9090/graph?g0.expr=increase%28kube_pod_container_status_restarts_total%5B5m%5D%29+%3E+1&g0.tab=1",
          fingerprint: "fb1ae09cb86a3c47"
        }],
        groupLabels: {
          alertname: "ContainerRestarted",
          instance: "testapp-kube-state-metrics.monitoring.svc:8080"
        },
        commonLabels: {
          alertname: "ContainerRestarted",
          app_kubernetes_io_component: "kube-state-metrics",
          app_kubernetes_io_name: "testapp",
          container: "testapp-api-worker",
          instance: "testapp-kube-state-metrics.monitoring.svc:8080",
          job: "kube-state-metrics",
          k8s_app: "kube-state-metrics",
          namespace: "testapp-test",
          pod: "testapp-test-api-worker-deployment-1234567890-abcef",
          severity: "critical"
        },
        commonAnnotations: {
          summary: "Container testapp-api-worker of pod testapp-test-api-worker-deployment-1234567890-abcef has been restarted"
        },
        externalURL: "http://127.0.01:9093",
        version: "4",
        groupKey: "{}:{alertname=\"ContainerRestarted\", instance=\"testapp-kube-state-metrics.monitoring.svc:8080\"}",
        truncatedAlerts: 0
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:status] = "resolved"

      @other_request = @create_request.deep_dup
      @other_request[:status] = "baaad"
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
      assert_equal @create_request.dig(:groupKey), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.dig("commonLabels", "alertname"),
        description: @create_request.dig("commonAnnotations", "summary"),
        urgency: "critical",
        thirdparty_id: @create_request.dig(:groupKey),
        dedup_keys: [@create_request.dig(:groupKey)],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Alert Manager URL", value: @create_request.dig("externalURL")),
          AdditionalDatum.new(format: "text", label: "Receiver", value: @create_request.dig("receiver"))
        ] + @create_request.dig("commonLabels").map do |key, value|
          AdditionalDatum.new(format: "text", label: key, value: value.to_s)
        end
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
