require "test_helper"

module PagerTree::Integrations
  class Honeybadger::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:honeybadger_v3)

      @create_fault_request = {
        event: "occurred",
        message: "[PT4/staging] Redis::CannotConnectError: Error connecting to Redis on ec2-100-25-210-31.compute-1.amazonaws.com:26009 (SocketError)",
        project: {
          id: 85696,
          name: "PT4",
          created_at: "2021-04-26T13:55:04.260933Z",
          disable_public_links: false,
          pivotal_project_id: nil,
          asana_workspace_id: nil,
          token: "cc614e8d",
          github_project: "PagerTree/pt4-app",
          environments: [
            {
              id: 136976,
              project_id: 85696,
              name: "production",
              notifications: true,
              created_at: "2021-07-08T19:32:20.607586Z",
              updated_at: "2021-07-08T19:32:20.607586Z"
            },
            {
              id: 127484,
              project_id: 85696,
              name: "staging",
              notifications: true,
              created_at: "2021-04-26T17:13:43.707745Z",
              updated_at: "2021-04-26T17:13:43.707745Z"
            },
            {
              id: 127466,
              project_id: 85696,
              name: "development",
              notifications: false,
              created_at: "2021-04-26T16:10:23.223590Z",
              updated_at: "2021-04-26T17:29:56.444969Z"
            }
          ],
          owner: {
            id: 90585,
            email: "amiller@pagertree.com",
            name: "PagerTree LLC"
          },
          last_notice_at: "2021-08-05T06:48:50.000000Z",
          earliest_notice_at: "2021-05-07T06:48:58.842071Z",
          unresolved_fault_count: 4,
          fault_count: 13,
          active: true,
          users: [
            {
              id: 88312,
              email: "amiller@pagertree.com",
              name: "Austin Miller"
            }
          ],
          sites: [],
          team_id: nil
        },
        fault: {
          project_id: 85696,
          klass: "Redis::CannotConnectError",
          component: nil,
          action: nil,
          environment: "staging",
          resolved: false,
          ignored: false,
          created_at: "2021-08-05T06:48:52.468252Z",
          comments_count: 0,
          message: "Error connecting to Redis on ec2-100-25-210-31.compute-1.amazonaws.com:26009 (SocketError)",
          notices_count: 1,
          last_notice_at: "2021-08-05T06:48:50.262951Z",
          tags: [],
          id: 80770669,
          assignee: nil,
          url: "https://app.honeybadger.io/projects/85696/faults/80770669",
          deploy: nil
        },
        notice: {
          id: 807706691628146130,
          environment: {},
          created_at: "2021-08-05T06:48:50.262951Z",
          message: nil,
          token: "2f84c968-3db7-46c9-8cff-afe33de3eaac",
          fault_id: 80770669,
          request: {
            url: nil,
            component: nil,
            action: nil,
            params: {},
            session: {}
          },
          application_trace: [],
          web_environment: {},
          deploy: nil,
          url: "https://app.honeybadger.io/projects/85696/faults/80770669/01FCAH4QAPCXTQJ31EHQ8NM9Q4"
        },
        context: {}
      }.with_indifferent_access

      @create_site_request = {
        event: "down",
        message: "[PT4] Mocky is down.",
        project: {
          id: 85696,
          name: "PT4",
          created_at: "2021-04-26T13:55:04.260933Z",
          disable_public_links: false,
          pivotal_project_id: nil,
          asana_workspace_id: nil,
          token: "cc614e8d",
          github_project: "PagerTree/pt4-app",
          environments: [
            {
              id: 127466,
              project_id: 85696,
              name: "development",
              notifications: true,
              created_at: "2021-04-26T16:10:23.223590Z",
              updated_at: "2021-08-23T20:46:06.270686Z"
            },
            {
              id: 136976,
              project_id: 85696,
              name: "production",
              notifications: true,
              created_at: "2021-07-08T19:32:20.607586Z",
              updated_at: "2021-07-08T19:32:20.607586Z"
            },
            {
              id: 127484,
              project_id: 85696,
              name: "staging",
              notifications: true,
              created_at: "2021-04-26T17:13:43.707745Z",
              updated_at: "2021-04-26T17:13:43.707745Z"
            }
          ],
          owner: {
            id: 90585,
            email: "amiller@pagertree.com",
            name: "PagerTree LLC"
          },
          last_notice_at: "2021-08-23T20:58:30.000000Z",
          earliest_notice_at: "2021-05-25T21:16:50.195864Z",
          unresolved_fault_count: 6,
          fault_count: 16,
          active: true,
          users: [
            {
              id: 88312,
              email: "amiller@pagertree.com",
              name: "Austin Miller"
            }
          ],
          sites: [
            {
              id: "37a5a602-f049-46ac-9a64-e8db6079dc80",
              active: true,
              last_checked_at: "2021-08-23T21:15:48.288724Z",
              name: "Mocky",
              state: "down",
              url: "https://run.mocky.io/v3/834874da-c15f-4310-bd45-f4913f4d23f1"
            }
          ],
          team_id: nil
        },
        site: {
          id: "37a5a602-f049-46ac-9a64-e8db6079dc80",
          name: "Mocky",
          url: "https://run.mocky.io/v3/834874da-c15f-4310-bd45-f4913f4d23f1",
          frequency: 1,
          match_type: "success",
          match: nil,
          state: "down",
          active: true,
          last_checked_at: "2021-08-23T21:15:48.288724Z",
          retries: 1,
          proxy: 0,
          details_url: "https://app.honeybadger.io/projects/85696/sites/37a5a602-f049-46ac-9a64-e8db6079dc80"
        },
        outage: {
          down_at: "2021-08-23T21:16:50.149481Z",
          up_at: nil,
          status: 500,
          reason: "Expected 2xx status code -- got 500",
          headers: {
            date: "Mon, 23 Aug 2021 21:16:49 GMT",
            "sozu-id": "01FDTDYZYP5QB3QX3M9Y7HY8T7",
            "content-type": "application/json; charset=UTF-8",
            "content-length": "0"
          },
          details_url: "https://app.honeybadger.io/projects/85696/sites/37a5a602-f049-46ac-9a64-e8db6079dc80"
        }
      }.with_indifferent_access

      @create_check_in_request = {
        event: "check_in_missing",
        message: "[PT4] MISSING: Test hasn't checked in for 2 minutes",
        project: {
          id: 85696,
          name: "PT4",
          created_at: "2021-04-26T13:55:04.260933Z",
          disable_public_links: false,
          pivotal_project_id: nil,
          asana_workspace_id: nil,
          token: "cc614e8d",
          github_project: "PagerTree/pt4-app",
          environments: [
            {
              id: 127466,
              project_id: 85696,
              name: "development",
              notifications: true,
              created_at: "2021-04-26T16:10:23.223590Z",
              updated_at: "2021-08-26T16:28:50.764581Z"
            },
            {
              id: 136976,
              project_id: 85696,
              name: "production",
              notifications: true,
              created_at: "2021-07-08T19:32:20.607586Z",
              updated_at: "2021-07-08T19:32:20.607586Z"
            },
            {
              id: 127484,
              project_id: 85696,
              name: "staging",
              notifications: true,
              created_at: "2021-04-26T17:13:43.707745Z",
              updated_at: "2021-04-26T17:13:43.707745Z"
            }
          ],
          owner: {
            id: 90585,
            email: "amiller@pagertree.com",
            name: "PagerTree LLC"
          },
          last_notice_at: "2021-08-23T20:58:30.000000Z",
          earliest_notice_at: "2021-05-28T17:27:04.540250Z",
          unresolved_fault_count: 6,
          fault_count: 16,
          active: true,
          users: [
            {
              id: 88312,
              email: "amiller@pagertree.com",
              name: "Austin Miller"
            }
          ],
          sites: [
            {
              id: "37a5a602-f049-46ac-9a64-e8db6079dc80",
              active: true,
              last_checked_at: "2021-08-26T17:26:24.585442Z",
              name: "Mocky",
              state: "up",
              url: "https://run.mocky.io/v3/544e1bb2-3cfb-4a47-8368-d7f2a31093f1"
            }
          ],
          team_id: nil
        },
        check_in: {
          state: "missing",
          schedule_type: "simple",
          reported_at: "2021-08-26T17:25:12.065726Z",
          expected_at: "2021-08-26T17:28:04.477334Z",
          missed_count: 1,
          grace_period: "",
          id: "vOIMp4",
          name: "Test",
          url: "https://api.honeybadger.io/v1/check_in/vOIMp4",
          details_url: "https://app.honeybadger.io/projects/85696/check_ins",
          report_period: "1 minute"
        }
      }.with_indifferent_access

      @resolve_fault_request = @create_fault_request.deep_dup
      @resolve_fault_request[:event] = "resolved"

      @resolve_site_request = @create_site_request.deep_dup
      @resolve_site_request[:event] = "up"

      @resolve_check_in_request = @create_check_in_request.deep_dup
      @resolve_check_in_request[:event] = "check_in_reporting"

      @other_request = @create_fault_request.deep_dup
      @other_request[:event] = "baaad"
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
      @integration.adapter_incoming_request_params = @create_fault_request
      assert_equal :create, @integration.adapter_action

      @integration.adapter_incoming_request_params = @create_site_request
      assert_equal :create, @integration.adapter_action

      @integration.adapter_incoming_request_params = @create_check_in_request
      assert_equal :create, @integration.adapter_action

      @integration.adapter_incoming_request_params = @resolve_fault_request
      assert_equal :resolve, @integration.adapter_action

      @integration.adapter_incoming_request_params = @resolve_site_request
      assert_equal :resolve, @integration.adapter_action

      @integration.adapter_incoming_request_params = @resolve_check_in_request
      assert_equal :resolve, @integration.adapter_action

      @integration.adapter_incoming_request_params = @other_request
      assert_equal :other, @integration.adapter_action
    end

    test "adapter_thirdparty_id" do
      @integration.adapter_incoming_request_params = @create_fault_request
      assert_equal @create_fault_request.dig("fault", "url"), @integration.adapter_thirdparty_id
      assert @integration.adapter_thirdparty_id

      @integration.adapter_incoming_request_params = @create_site_request
      assert_equal @create_site_request.dig("outage", "details_url"), @integration.adapter_thirdparty_id
      assert @integration.adapter_thirdparty_id

      @integration.adapter_incoming_request_params = @create_check_in_request
      assert_equal @create_check_in_request.dig("check_in", "details_url"), @integration.adapter_thirdparty_id
      assert @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      # TEST THE FAULT REQUEST
      @integration.adapter_incoming_request_params = @create_fault_request

      true_alert = Alert.new(
        title: @create_fault_request.dig("message"),
        urgency: nil,
        thirdparty_id: @create_fault_request.dig("fault", "url"),
        dedup_keys: [@create_fault_request.dig("fault", "url")],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Fault URL", value: @create_fault_request.dig("fault", "url")),
          AdditionalDatum.new(format: "text", label: "Environment", value: @create_fault_request.dig("fault", "environment")),
          AdditionalDatum.new(format: "link", label: "Outage URL", value: nil),
          AdditionalDatum.new(format: "link", label: "Check In URL", value: nil)
        ],
        tags: Array(@create_fault_request.dig("fault", "tags")) + Array(@create_fault_request.dig("fault", "environment"))
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json

      # TEST THE SITE REQUEST
      @integration.adapter_incoming_request_params = @create_site_request

      true_alert = Alert.new(
        title: @create_site_request.dig("message"),
        urgency: nil,
        thirdparty_id: @create_site_request.dig("outage", "details_url"),
        dedup_keys: [@create_site_request.dig("outage", "details_url")],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Fault URL", value: nil),
          AdditionalDatum.new(format: "text", label: "Environment", value: nil),
          AdditionalDatum.new(format: "link", label: "Outage URL", value: @create_site_request.dig("outage", "details_url")),
          AdditionalDatum.new(format: "link", label: "Check In URL", value: nil)
        ],
        tags: []
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json

      # TEST THE CHECK_IN REQUEST
      @integration.adapter_incoming_request_params = @create_check_in_request

      true_alert = Alert.new(
        title: @create_check_in_request.dig("message"),
        urgency: nil,
        thirdparty_id: @create_check_in_request.dig("check_in", "details_url"),
        dedup_keys: [@create_check_in_request.dig("check_in", "details_url")],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Fault URL", value: nil),
          AdditionalDatum.new(format: "text", label: "Environment", value: nil),
          AdditionalDatum.new(format: "link", label: "Outage URL", value: nil),
          AdditionalDatum.new(format: "link", label: "Check In URL", value: @create_check_in_request.dig("check_in", "details_url"))
        ],
        tags: []
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end

    test "blocking_incoming" do
      @blocked_request = @create_request.deep_dup
      @integration.option_token = "abc123"
      assert @integration.adapter_should_block_incoming?(OpenStruct.new({headers: {"honeybadger-token" => ""}}))
      assert_not @integration.adapter_should_block_incoming?(OpenStruct.new({headers: {"honeybadger-token" => "abc123"}}))
    end
  end
end
