require "test_helper"

module PagerTree::Integrations
  class JiraServer::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:jira_server_v3)

      @create_request = {
        id: 2,
        timestamp: 1525698237764,
        issue: {
          id: "99291",
          self: "https://jira.atlassian.com/rest/api/2/issue/99291",
          key: "JRA-20002",
          fields: {
            summary: "I feel the need for speed",
            created: "2009-12-16T23:46:10.612-0600",
            description: "Make the issue nav load 10x faster",
            labels: ["UI", "dialogue", "move"],
            priority: "Minor"
          }
        },
        user: {
          self: "https://jira.atlassian.com/rest/api/2/user?username=brollins",
          name: "brollins",
          key: "brollins",
          emailAddress: "bryansemail at atlassian dot com",
          avatarUrls: {
            "16x16": "https://jira.atlassian.com/secure/useravatar?size=small&avatarId=10605",
            "48x48": "https://jira.atlassian.com/secure/useravatar?avatarId=10605"
          },
          displayName: "Bryan Rollins [Atlassian]",
          active: true
        },
        changelog: {
          items: [
            {
              toString: "A new summary.",
              to: nil,
              fromString: "What is going on here?????",
              from: nil,
              fieldtype: "jira",
              field: "summary"
            },
            {
              toString: "New Feature",
              to: "2",
              fromString: "Improvement",
              from: "4",
              fieldtype: "jira",
              field: "issuetype"
            }
          ],
          id: 10124
        },
        comment: {
          self: "https://jira.atlassian.com/rest/api/2/issue/10148/comment/252789",
          id: "252789",
          author: {
            self: "https://jira.atlassian.com/rest/api/2/user?username=brollins",
            name: "brollins",
            emailAddress: "bryansemail@atlassian.com",
            avatarUrls: {
              "16x16": "https://jira.atlassian.com/secure/useravatar?size=small&avatarId=10605",
              "48x48": "https://jira.atlassian.com/secure/useravatar?avatarId=10605"
            },
            displayName: "Bryan Rollins [Atlassian]",
            active: true
          },
          body: "Just in time for AtlasCamp!",
          updateAuthor: {
            self: "https://jira.atlassian.com/rest/api/2/user?username=brollins",
            name: "brollins",
            emailAddress: "brollins@atlassian.com",
            avatarUrls: {
              "16x16": "https://jira.atlassian.com/secure/useravatar?size=small&avatarId=10605",
              "48x48": "https://jira.atlassian.com/secure/useravatar?avatarId=10605"
            },
            displayName: "Bryan Rollins [Atlassian]",
            active: true
          },
          created: "2011-06-07T10:31:26.805-0500",
          updated: "2011-06-07T10:31:26.805-0500"
        },
        webhookEvent: "jira:issue_created"
      }.with_indifferent_access

      @issue_updated_request = @create_request.deep_dup
      @issue_updated_request[:webhookEvent] = "jira:issue_updated"

      @other_request = @create_request.deep_dup
      @other_request[:webhookEvent] = "baaad"
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

      # check that it respects the issue updated flag
      @integration.adapter_incoming_request_params = @issue_updated_request
      assert_equal :other, @integration.adapter_action

      @integration.option_issue_updated = true
      assert_equal :create, @integration.adapter_action

      @integration.adapter_incoming_request_params = @other_request
      assert_equal :other, @integration.adapter_action
    end

    test "adapter_thirdparty_id" do
      @integration.adapter_incoming_request_params = @create_request
      assert_equal @create_request.dig("issue", "id"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: @create_request.dig("issue", "fields", "summary"),
        description: @create_request.dig("issue", "fields", "description"),
        urgency: nil,
        thirdparty_id: @create_request.dig("issue", "id"),
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Issue URL", value: @create_request.dig("issue", "self"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
