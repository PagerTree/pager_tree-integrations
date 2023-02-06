require "test_helper"

module PagerTree::Integrations
  class UptimeKuma::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:uptime_kuma_v3)

      # TODO: Write some requests to test the integration
      @create_request = {
        event_type: "create",
        id: 1,
        title: "Uptime Kuma Monitor \"Marketing\" is down",
        urgency: "high",
        heartbeat: {
          monitorID: 1,
          status: 0,
          time: "2023-02-06 18:07:43.733",
          msg: "Request failed with status code 500",
          important: true,
          duration: 27
        },
        monitor: {
          id: 1,
          name: "Marketing",
          url: "https://mock.codes/500",
          method: "GET",
          hostname: nil,
          port: nil,
          maxretries: 0,
          weight: 2000,
          active: 1,
          type: "http",
          interval: 60,
          retryInterval: 60,
          resendInterval: 0,
          keyword: nil,
          expiryNotification: false,
          ignoreTls: false,
          upsideDown: false,
          packetSize: 56,
          maxredirects: 10,
          accepted_statuscodes: [
            "200-299"
          ],
          dns_resolve_type: "A",
          dns_resolve_server: "1.1.1.1",
          dns_last_result: nil,
          docker_container: "",
          docker_host: nil,
          proxyId: nil,
          notificationIDList: {
            "1": true
          },
          tags: [
            {
              id: 1,
              monitor_id: 1,
              tag_id: 1,
              value: "prod",
              name: "production",
              color: "#DC2626"
            }
          ],
          maintenance: false,
          mqttTopic: "",
          mqttSuccessMessage: "",
          databaseQuery: nil,
          authMethod: nil,
          grpcUrl: nil,
          grpcProtobuf: nil,
          grpcMethod: nil,
          grpcServiceName: nil,
          grpcEnableTls: false,
          radiusCalledStationId: nil,
          radiusCallingStationId: nil,
          game: nil,
          includeSensitiveData: false
        }
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:event_type] = "resolve"

      @other_request = @create_request.deep_dup
      @other_request[:event_type] = "other"
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
        title: @create_request.dig(:title),
        description: @create_request.dig("heartbeat", "msg"),
        urgency: :high,
        thirdparty_id: @create_request.dig(:id),
        dedup_keys: [],
        tags: @create_request.dig("monitor", "tags").map { |x| x["name"] }.compact_blank.map(&:to_s).uniq,
        additional_data: [
          AdditionalDatum.new(format: "link", label: "URL", value: @create_request.dig("monitor", "url")),
          AdditionalDatum.new(format: "text", label: "Method", value: @create_request.dig("monitor", "method")),
          AdditionalDatum.new(format: "datetime", label: "Time", value: @create_request.dig("heartbeat", "time"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
