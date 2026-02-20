require "test_helper"

module PagerTree::Integrations
  class Email::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:email_v3)

      @integration.singleton_class.class_eval do
        attr_accessor :v, :urgency, :prefix_id
      end

      @integration.v = 3
      @integration.urgency = "medium"
      @integration.prefix_id = "int_xxxyyy"

      # Default state - no custom definition
      @integration.option_custom_definition_enabled = false
      @integration.option_custom_definition = nil
      @integration.option_dedup_threads = true
      @integration.option_allow_spam = false
      @integration.option_sanitize_level = "relaxed"

      # Basic mail used for non-custom tests
      @basic_mail = Mail.new do
        from "sender@example.com"
        to "inbox@pagertree.com"
        subject "Test Subject: Incoming Alert"
        body "This is the plain-text body"
        message_id "basic-12345@example.com"
      end

      @integration.adapter_incoming_request_params = {"mail" => @basic_mail}

      # Mails for custom-definition tests (different subjects trigger different rules)
      @down_mail = Mail.new do
        from "alerts@server.com"
        to "inbox@pagertree.com"
        subject "Server is DOWN right now"
        body "Full downtime details here..."
        message_id "down-98765@server.com"
      end

      @ack_mail = @down_mail.dup.tap { |m| m.subject = "Server is PENDING maintenance" }
      @resolve_mail = @down_mail.dup.tap { |m| m.subject = "Server is UP again" }
      @other_mail = @down_mail.dup.tap { |m| m.subject = "Paused" }
    end

    # ===================================================================
    # Sanity / basic adapter methods
    # ===================================================================
    test "sanity" do
      assert @integration.adapter_supports_incoming?
      assert_not @integration.adapter_supports_outgoing?
      assert @integration.adapter_show_alerts?
      assert @integration.adapter_show_logs?
      assert_not @integration.adapter_show_outgoing_webhook_delivery?
    end

    test "endpoint in test environment" do
      assert_match %r{_tst\+}, @integration.endpoint
      assert_includes @integration.endpoint, "@"
    end

    # ===================================================================
    # adapter_should_block?
    # ===================================================================
    test "adapter_should_block? is false by default (no spam header)" do
      assert_not @integration.adapter_should_block?
    end

    test "adapter_should_block? returns true when SES marks as spam" do
      spam_mail = @basic_mail.dup
      spam_mail.header["X-SES-Spam-Verdict"] = "FAIL"

      @integration.adapter_incoming_request_params = {"mail" => spam_mail}
      assert @integration.adapter_should_block?
    end

    test "adapter_should_block? respects option_allow_spam = true" do
      @integration.option_allow_spam = true

      spam_mail = @basic_mail.dup
      spam_mail.header["X-SES-Spam-Verdict"] = "FAIL"

      @integration.adapter_incoming_request_params = {"mail" => spam_mail}
      assert_not @integration.adapter_should_block?
    end

    # ===================================================================
    # adapter_action (non-custom)
    # ===================================================================
    test "adapter_action is always :create when custom_definition is disabled" do
      assert_equal :create, @integration.adapter_action
    end

    # ===================================================================
    # Custom definition tests (uses the shared custom webhook service)
    # ===================================================================
    test "adapter_action_create with custom definition" do
      setup_custom_definition

      VCR.use_cassette("email_v3_custom_adapter_action_create") do
        @integration.adapter_incoming_request_params = {"mail" => @down_mail}
        assert_equal :create, @integration.adapter_action
      end
    end

    test "adapter_action_acknowledge with custom definition" do
      setup_custom_definition

      VCR.use_cassette("email_v3_custom_adapter_action_acknowledge") do
        @integration.adapter_incoming_request_params = {"mail" => @ack_mail}
        assert_equal :acknowledge, @integration.adapter_action
      end
    end

    test "adapter_action_resolve with custom definition" do
      setup_custom_definition

      VCR.use_cassette("email_v3_custom_adapter_action_resolve") do
        @integration.adapter_incoming_request_params = {"mail" => @resolve_mail}
        assert_equal :resolve, @integration.adapter_action
      end
    end

    test "adapter_action_other with custom definition" do
      setup_custom_definition

      VCR.use_cassette("email_v3_custom_adapter_action_other") do
        @integration.adapter_incoming_request_params = {"mail" => @other_mail}
        assert_equal :other, @integration.adapter_action
      end
    end

    test "adapter_thirdparty_id with custom definition" do
      setup_custom_definition

      VCR.use_cassette("email_v3_custom_adapter_thirdparty_id") do
        @integration.adapter_incoming_request_params = {"mail" => @down_mail}
        assert_equal "email-test-123", @integration.adapter_thirdparty_id
      end
    end

    test "adapter_process_create default (no custom definition)" do
      alert = @integration.adapter_process_create

      assert_equal "Test Subject: Incoming Alert", alert.title
      assert_equal "This is the plain-text body", alert.description
      assert_equal "medium", alert.urgency
      assert_equal "basic-12345@example.com", alert.thirdparty_id
      assert_equal 3, alert.additional_data.size
      assert_equal "email", alert.additional_data.first.format
    end

    test "adapter_process_create with custom definition" do
      setup_custom_definition
      @integration.option_dedup_threads = false # makes expected dedup_keys deterministic

      VCR.use_cassette("email_v3_custom_adapter_process_create") do
        @integration.adapter_incoming_request_params = {"mail" => @down_mail}

        expected_alert = Alert.new(
          title: "Server is DOWN right now",
          description: "Full downtime details here...",
          urgency: "high",
          thirdparty_id: "email-test-123",
          dedup_keys: [], # because we disabled dedup_threads + no dedup_keys in rule
          incident: true,
          incident_severity: "SEV-1",
          incident_message: "Check the email thread",
          tags: ["email", "alert"],
          meta: {"source" => "email"},
          additional_data: [
            AdditionalDatum.new(format: "email", label: "From", value: "alerts@server.com")
          ],
          attachments: []
        )

        assert_equal expected_alert.to_json, @integration.adapter_process_create.to_json
      end
    end

    private

    def setup_custom_definition
      @yml_definition ||= <<~YAML
        ---
        rules:
          - match:
              log.subject: { $regex: "down", $options: "i" }
            actions:
              - type: create
                title: "{{log.subject}}"
                description: "{{log.body}}"
                urgency: "high"
                thirdparty_id: "email-test-123"
                incident: "true"
                incident_severity: "SEV-1"
                incident_message: "Check the email thread"
                tags:
                  - email
                  - alert
                meta:
                  source: "email"
                additional_data:
                  - format: email
                    label: From
                    value: "{{log.from}}"

          - match:
              log.subject: { $regex: "pending", $options: "i" }
            actions:
              - type: acknowledge
                thirdparty_id: "email-test-123"

          - match:
              log.subject: { $regex: "up", $options: "i" }
            actions:
              - type: resolve
                thirdparty_id: "email-test-123"

          - match:
              log.subject: "Paused"
            actions:
              - type: ignore
      YAML

      @integration.option_custom_definition_enabled = true
      @integration.option_custom_definition = @yml_definition
    end
  end
end
