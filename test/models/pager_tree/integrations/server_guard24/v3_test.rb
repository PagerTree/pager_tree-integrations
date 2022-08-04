require "test_helper"

module PagerTree::Integrations
  class ServerGuard24::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:server_guard24_v3)

      @create_request = {
        server_name: "Example App (Hosts and SSL)",
        server_address: "serverguard.example.com",
        service_name: "Local Web",
        service_shortname: "bo-web-p02",
        service_message: "",
        check_result: "CRITICAL",
        check_output: "FAILURE: memory[memused=82.57% (>80%), swapuse=0.00%]",
        notification_time: "04.08.2022 17:07:20",
        service_arg_path: "/bo-web-p02",
        service_arg_searchitem_ok: "OK",
        service_arg_searchitem_warning: "WARNING",
        service_arg_searchitem_critical: "FAILURE",
        service_arg_timeout: "30",
        service_arg_port: "443",
        service_arg_ssl: "1",
        service_arg_searchitem_none: "2",
        service_arg_login: "",
        service_arg_debug_addon: "",
        service_arg_performance: "0",
        service_arg_perfname: "Performance",
        service_arg_perfunit: "s",
        service_arg_perfdigits: "2",
        service_arg_hostheader: ""
      }.with_indifferent_access

      @resolve_request = @create_request.deep_dup
      @resolve_request[:check_result] = "OK"

      @resolve_request_warn = @create_request.deep_dup
      @resolve_request_warn[:check_result] = "WARNING"

      @other_request = @create_request.deep_dup
      @other_request[:check_result] = "baaad"
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

      # check that it respect the resolve on warn flag
      @integration.adapter_incoming_request_params = @resolve_request_warn
      assert_equal :other, @integration.adapter_action
      @integration.option_resolve_warn = true
      assert_equal :resolve, @integration.adapter_action
      @integration.option_resolve_warn = false

      @integration.adapter_incoming_request_params = @other_request
      assert_equal :other, @integration.adapter_action
    end

    test "adapter_thirdparty_id" do
      @integration.adapter_incoming_request_params = @create_request
      assert_equal thirdparty_id, @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: "#{@create_request.dig("server_name")} is DOWN",
        description: "#{@create_request.dig("server_name")} is DOWN because #{@create_request.dig("check_output")}",
        urgency: nil,
        thirdparty_id: thirdparty_id,
        dedup_keys: [thirdparty_id],
        additional_data: [
          AdditionalDatum.new(format: "text", label: "Server Name", value: @create_request.dig("server_name")),
          AdditionalDatum.new(format: "text", label: "Server Address", value: @create_request.dig("server_address")),
          AdditionalDatum.new(format: "text", label: "Service Name", value: @create_request.dig("service_name")),
          AdditionalDatum.new(format: "text", label: "Service Short Name", value: @create_request.dig("service_shortname")),
          AdditionalDatum.new(format: "datetime", label: "Notification Time", value: @create_request.dig("notification_time")),
          AdditionalDatum.new(format: "text", label: "Check Result", value: @create_request.dig("check_result")),
          AdditionalDatum.new(format: "text", label: "Check Output", value: @create_request.dig("check_output"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    def thirdparty_id
      [@create_request.dig("server_name"), @create_request.dig("service_shortname")].compact_blank.join("_")
    end
  end
end
