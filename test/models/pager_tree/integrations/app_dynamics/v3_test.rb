require "test_helper"

module PagerTree::Integrations
  class AppDynamics::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:app_dynamics_v3)

      # TODO: Write some requests to test the integration
      @create_request = {
        incident_key: "${latestEvent.node.name} - ${latestEvent.application.name}",
        event_type: "trigger",
        description: "${latestEvent.displayName} on ${latestEvent.node.name}",
        client: "AppDynamics",
        client_url: "${controllerUrl}",
        details: {
          event_name: "${latestEvent.displayName}",
          summary: "${latestEvent.summaryMessage}",
          event_id: "${latestEvent.id}",
          guid: "${latestEvent.guid}",
          event_time: "${latestEvent.eventTime}",
          event_type: "${latestEvent.eventType}",
          event_type_key: "${latestEvent.eventTypeKey}",
          application_name: "${latestEvent.application.name}",
          node_name: "${latestEvent.node.name}",
          message: "${latestEvent.eventMessage}",
          severity: "${latestEvent.severity}"
        },
        contexts: [
          {
            type: "image",
            src: "${latestEvent.severityImage.deepLink}",
            alt: "${latestEvent.severity}"
          },
          {
            type: "link",
            href: "${latestEvent.deepLink}",
            text: "View this transaction in AppDynamics"
          }
        ]
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:event_type] = "resolve"

      @other_request = @create_request.deep_dup
      @other_request[:event_type] = "baaad"
    end

    test "sanity" do
      # TODO: Check some sane defaults your integration should have
      assert @integration.adapter_supports_incoming?
      assert @integration.adapter_incoming_can_defer?
      assert_not @integration.adapter_supports_outgoing?
      assert @integration.adapter_show_alerts?
      assert @integration.adapter_show_logs?
      assert_not @integration.adapter_show_outgoing_webhook_delivery?
    end

    test "adapter_actions" do
      # TODO: Check that the adapter_actions returns expected results based on the inputs
      @integration.adapter_incoming_request_params = @create_request
      assert_equal :create, @integration.adapter_action

      @integration.adapter_incoming_request_params = @resolve_request
      assert_equal :resolve, @integration.adapter_action

      @integration.adapter_incoming_request_params = @other_request
      assert_equal :other, @integration.adapter_action
    end

    test "adapter_thirdparty_id" do
      # TODO: Check that the third party id comes back as expected
      @integration.adapter_incoming_request_params = @create_request
      assert_equal "${latestEvent.id}", @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      # TODO: Check tthe entire transform
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: "${latestEvent.node.name} - ${latestEvent.application.name}",
        description: "${latestEvent.displayName} on ${latestEvent.node.name}\n\n${latestEvent.summaryMessage}",
        urgency: nil,
        thirdparty_id: "${latestEvent.id}",
        dedup_keys: ["${latestEvent.id}"],
        additional_data: [
          AdditionalDatum.new(format: "text", label: "Event Name", value: "${latestEvent.displayName}"),
          AdditionalDatum.new(format: "datetime", label: "Event Time", value: "${latestEvent.eventTime}"),
          AdditionalDatum.new(format: "text", label: "Application Name", value: "${latestEvent.application.name}"),
          AdditionalDatum.new(format: "text", label: "Node Name", value: "${latestEvent.node.name}"),
          AdditionalDatum.new(format: "img", label: "${latestEvent.severity}", value: "${latestEvent.severityImage.deepLink}"),
          AdditionalDatum.new(format: "link", label: "View this transaction in AppDynamics", value: "${latestEvent.deepLink}")
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
