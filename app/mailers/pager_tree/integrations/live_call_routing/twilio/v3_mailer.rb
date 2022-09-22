module PagerTree::Integrations
  class LiveCallRouting::Twilio::V3Mailer < ::ApplicationMailer
    # Subject can be set in your I18n file at config/locales/en.yml
    # with the following lookup:
    #
    #   en.live_call_routing.twilio.v3_mailer.call_recording.subject
    #
    def call_recording
      @recording_url = params[:recording_url]
      @alert = params[:alert]
      @email = params[:email]
      @from = params[:from]

      mail(to: @email, subject: I18n.t("pager_tree.integrations.live_call_routing.twilio.v3_mailer.call_recording.subject", tiny_id: @alert.tiny_id, from: @from))
    end
  end
end
