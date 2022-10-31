require "test_helper"

module PagerTree::Integrations
  class Grafana::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:grafana_v3)

      # http://docs.grafana.org/alerting/notifications/#webhook
      @create_request = {
        title: "My alert",
        ruleId: 1,
        ruleName: "Load peaking!",
        ruleUrl: "http://url.to.grafana/db/dashboard/my_dashboard?panelId=2",
        state: "alerting",
        imageUrl: "http://s3.image.url",
        message: "Load is peaking. Make sure the traffic is real and spin up more webfronts",
        evalMatches: [
          {
            metric: "requests",
            tags: {},
            value: 122
          }
        ]
      }.with_indifferent_access

      @create_request_2 = {
        receiver: "",
        status: "firing",
        alerts: [
          {
            status: "firing",
            labels: {
              alertname: "TestAlert",
              instance: "Grafana"
            },
            annotations: {
              summary: "Notification test"
            },
            startsAt: "2022-10-31T21:42:32.8794896Z",
            endsAt: "0001-01-01T00:00:00Z",
            generatorURL: "",
            fingerprint: "57c6d9296de2ad39",
            silenceURL: "https://url.to.grafana/alerting/silence/new?alertmanager=grafana&matcher=alertname%3DTestAlert&matcher=instance%3DGrafana",
            dashboardURL: "",
            panelURL: "",
            valueString: "[ metric='foo' labels={instance=bar} value=10 ]"
          }
        ],
        groupLabels: {},
        commonLabels: {
          alertname: "TestAlert",
          instance: "Grafana"
        },
        commonAnnotations: {
          summary: "Notification test"
        },
        externalURL: "https://url.to.grafana/",
        version: "1",
        groupKey: "{alertname=\"TestAlert\", instance=\"Grafana\"}2022-10-31 21:42:32.8794896 +0000 UTC m=+2091531.637929403",
        truncatedAlerts: 0,
        orgId: 1,
        title: "[FIRING:1]  (TestAlert Grafana)",
        state: "alerting",
        message: "**Firing**\n\nValue: [ metric='foo' labels={instance=bar} value=10 ]\nLabels:\n - alertname = TestAlert\n - instance = Grafana\nAnnotations:\n - summary = Notification test\nSilence: https://url.to.grafana/alerting/silence/new?alertmanager=grafana&matcher=alertname%3DTestAlert&matcher=instance%3DGrafana\n"
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:state] = "ok"

      @other_request = @create_request.deep_dup
      @other_request[:state] = "baaad"
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
      assert_equal 1, @integration.adapter_thirdparty_id

      @integration.adapter_incoming_request_params = @create_request_2
      assert_equal @create_request_2.dig("groupKey"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.dig("ruleName"),
        description: @create_request.dig("message"),
        urgency: nil,
        thirdparty_id: @create_request.dig("ruleId"),
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "URL", value: @create_request.dig("ruleURL")),
          AdditionalDatum.new(format: "img", label: "Image", value: @create_request.dig("imageUrl"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json

      @integration.adapter_incoming_request_params = @create_request_2

      true_alert = Alert.new(
        title: @create_request_2.dig("title"),
        description: @create_request_2.dig("message"),
        urgency: nil,
        thirdparty_id: @create_request_2.dig("groupKey"),
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "URL", value: nil),
          AdditionalDatum.new(format: "img", label: "Image", value: nil)
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
