require "test_helper"

module PagerTree::Integrations
  class Twilio::IncomingSms::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:twilio_incoming_sms_v3)

      # TODO: Write some requests to test the integration
      @create_request = {
        AccountSid:	"AC00000000000000000",
        ApiVersion:	"2010-04-01",
        Body:	"Yo",
        From:	"+15555555555",
        FromCity:	"DALLAS",
        FromCountry:	"US",
        FromState:	"TX",
        FromZip:	"75234",
        MessageSid:	"SM111111111111111111111111",
        MessagingServiceSid:	"MG99999999999999999999",
        NumMedia:	"0",
        NumSegments:	"1",
        ReferralNumMedia:	"0",
        SmsMessageSid:	"SM111111111111111111111111",
        SmsSid:	"SM111111111111111111111111",
        SmsStatus:	"received",
        To:	"+15555555544",
        ToCity:	"CLUTE",
        ToCountry:	"US",
        ToState:	"TX",
        ToZip:	"77510"
      }.with_indifferent_access
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
    end

    test "adapter_thirdparty_id" do
      @integration.adapter_incoming_request_params = @create_request
      assert_equal @create_request.dig("MessageSid"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: "Incoming SMS from #{@create_request.dig("From")} - See description for details",
        description: @create_request.dig("Body"),
        urgency: nil,
        thirdparty_id: @create_request.dig("MessageSid"),
        dedup_keys: [@create_request.dig("MessageSid")],
        additional_data: [
          AdditionalDatum.new(format: "link", label: "Twilio URL", value: "https://www.twilio.com/console/sms/logs/#{@create_request.dig("MessageSid")}"),
          AdditionalDatum.new(format: "text", label: "Account SID", value: @create_request.dig("AccountSid")),
          AdditionalDatum.new(format: "text", label: "Message SID", value: @create_request.dig("MessageSid")),
          AdditionalDatum.new(format: "phone", label: "To", value: @create_request.dig("To")),
          AdditionalDatum.new(format: "phone", label: "From", value: @create_request.dig("From")),
          AdditionalDatum.new(format: "text", label: "From Country", value: @create_request.dig("FromCountry")),
          AdditionalDatum.new(format: "text", label: "From State", value: @create_request.dig("FromState")),
          AdditionalDatum.new(format: "text", label: "From City", value: @create_request.dig("FromCity")),
          AdditionalDatum.new(format: "text", label: "From Zip", value: @create_request.dig("FromZip"))
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
