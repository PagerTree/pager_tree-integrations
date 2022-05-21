require "test_helper"

module PagerTree::Integrations
  class Datadog::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:datadog_v3)

      @create_request = {
        ID: "$ID",
        EVENT_TITLE: "$EVENT_TITLE",
        TEXT_ONLY_MSG: "$TEXT_ONLY_MSG",
        EVENT_TYPE: "$EVENT_TYPE",
        LAST_UPDATED: "$LAST_UPDATED",
        AGGREG_KEY: "$AGGREG_KEY",
        DATE: "2016-05-24T20:10:57.657259407Z",
        USER: "$USER",
        SNAPSHOT: "$SNAPSHOT",
        LINK: "$LINK",
        PRIORITY: "$PRIORITY",
        TAGS: "prod,alert",
        ALERT_ID: "$ALERT_ID",
        ALERT_TITLE: "$ALERT_TITLE",
        ALERT_METRIC: "$ALERT_METRIC",
        ALERT_SCOPE: "$ALERT_SCOPE",
        ALERT_QUERY: "$ALERT_QUERY",
        ALERT_STATUS: "$ALERT_STATUS",
        ALERT_TRANSITION: "Triggered"
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:ALERT_TRANSITION] = "Recovered"

      @other_request = @create_request.deep_dup
      @other_request[:ALERT_TRANSITION] = "baaad"
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
      assert_equal @create_request[:ALERT_ID], @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request[:ALERT_TITLE],
        description: @create_request[:ALERT_STATUS],
        urgency: nil,
        thirdparty_id: @create_request[:ALERT_ID],
        dedup_keys: [@create_request[:ALERT_ID], @create_request[:AGGREG_KEY]].compact,
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Link", value: @create_request.dig("LINK")),
          AdditionalDatum.new(format: "text", label: "Priority", value: @create_request.dig("PRIORITY")),
          AdditionalDatum.new(format: "text", label: "Event Type", value: @create_request.dig("EVENT_TYPE")),
          AdditionalDatum.new(format: "text", label: "Event Title", value: @create_request.dig("EVENT_TITLE"))
        ],
        tags: @create_request[:TAGS].split(",").map(&:strip).uniq.compact
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
