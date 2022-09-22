require "test_helper"

module PagerTree::Integrations
  class LiveCallRouting::Twilio::V3MailerTest < ActionMailer::TestCase
    test "call_recording" do
      email = "to@example.org"
      alert = OpenStruct.new(tiny_id: 123)
      from = "+15555555555"
      recording_url = "https://example.org/recording.mp3"

      mail = LiveCallRouting::Twilio::V3Mailer.with(
        email: email,
        alert: alert,
        from: from,
        recording_url: recording_url
      ).call_recording
      assert_equal I18n.t("pager_tree.integrations.live_call_routing.twilio.v3_mailer.call_recording.subject", tiny_id: alert.tiny_id, from: from), mail.subject
      assert_equal [email], mail.to
    end
  end
end
