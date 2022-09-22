module PagerTree::Integrations
  # Preview all emails at http://localhost:3000/rails/mailers/live_call_routing/twilio/v3_mailer
  class LiveCallRouting::Twilio::V3MailerPreview < ActionMailer::Preview
    # Preview this email at http://localhost:3000/rails/mailers/live_call_routing/twilio/v3_mailer/call_recording
    def call_recording
      email = "to@example.org"
      alert = OpenStruct.new(tiny_id: 123)
      from = "+15555555555"
      recording_url = "https://example.org/recording.mp3"
      LiveCallRouting::Twilio::V3Mailer.with(
        email: email,
        alert: alert,
        from: from,
        recording_url: recording_url
      ).call_recording
    end
  end
end
