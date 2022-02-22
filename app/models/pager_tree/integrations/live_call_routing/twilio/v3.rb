module PagerTree::Integrations
  class LiveCallRouting::Twilio::V3 < Integration
    OPTIONS = [
      {key: :account_sid, type: :string, default: nil},
      {key: :api_key, type: :string, default: nil},
      {key: :api_secret, type: :string, default: nil},
      {key: :force_input, type: :boolean, default: false},
      {key: :record, type: :boolean, default: false},
      {key: :record_email, type: :string, default: ""}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    has_one_attached :option_connect_now_media
    has_one_attached :option_music_media
    has_one_attached :option_no_answer_media
    has_one_attached :option_no_answer_thank_you_media
    has_one_attached :option_please_wait_media
    has_one_attached :option_welcome_media

    validates :option_account_sid, presence: true
    validates :option_api_key, presence: true
    validates :option_api_secret, presence: true
    validates :option_force_input, inclusion: {in: [true, false]}
    validates :option_record, inclusion: {in: [true, false]}
    validate :validate_record_emails

    after_initialize do
      self.option_account_sid ||= nil
      self.option_api_key ||= nil
      self.option_api_secret ||= nil
      self.option_force_input ||= false
      self.option_record ||= false
      self.option_record_email ||= ""
    end

    SPEAK_OPTIONS = {
      language: "en",
      voice: "man"
    }

    TWILIO_LIVECALL_CONNECT_NOW = "https://app.pagertree.com/assets/sounds/you-are-now-being-connected.mp3"
    TWILIO_LIVECALL_MUSIC = "http://com.twilio.sounds.music.s3.amazonaws.com/oldDog_-_endless_goodbye_%28instr.%29.mp3"
    TWILIO_LIVECALL_PLEASE_WAIT = "https://app.pagertree.com/assets/sounds/please-wait.mp3"

    def option_connect_now_media_url
      option_connect_now_media&.url || TWILIO_LIVECALL_CONNECT_NOW
    end

    def option_music_media_url
      option_music_media&.url || TWILIO_LIVECALL_MUSIC
    end

    def option_please_wait_media_url
      option_please_wait_media&.url || TWILIO_LIVECALL_PLEASE_WAIT
    end

    def option_record_emails=(x)
      self.option_record_email = Array(x).join(",")
    end

    def option_record_emails
      self.option_record_email.split(",")
    end

    def option_record_emails_list=(x)
      # what comes in as json, via tagify
      uniq_array = []
      begin
        uniq_array = JSON.parse(x).map { |y| y["value"] }.uniq
      rescue JSON::ParserError => exception
        Rails.logger.debug(exception)
      end

      self.option_record_emails = uniq_array
    end

    def option_record_emails_list
      option_record_emails
    end

    def validate_record_emails
      errors.add(:record_emails, "must be a valid email") if option_record_emails.any? { |x| !x.match(URI::MailTo::EMAIL_REGEXP) }
    end

    def adapter_supports_incoming?
      true
    end

    def adapter_supports_outgoing?
      true
    end

    def adapter_incoming_can_defer?
      false
    end

    def adapter_action
      :create
    end

    def adapter_thirdparty_id
      _thirdparty_id
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        urgency: urgency,

        thirdparty_id: _thirdparty_id,
        dedup_keys: [_thirdparty_id],
        additional_data: _additional_datums
      )
    end

    def adapter_response_incoming
      if _teams_size == 0
        _twiml.say(message: "This integration is not configured to route to any teams. Goodbye", **SPEAK_OPTIONS)
        _twiml.hangup
        return adapter_controller&.render(xml: _twiml.to_xml)
      end

      if !adapter_alert.meta["live_call_welcome"] && option_welcome_media.present?
        adapter_alert.logs.create!(message: "Play welcome media to caller.")
        _twiml.play(url: option_welcome_media.url)
        adapter_alert.meta["live_call_welcome"] = true
        adapter_alert.save!
      end

      if selected_team
        adapter_alert.logs.create!(message: "Caller selected team '#{selected_team.name}'. Playing please wait media.")
        _twiml.play(url: option_please_wait_media&.url || TWILIO_LIVECALL_PLEASE_WAIT)
        friendly_name = adapter_alert.id

        # create the queue and save it off
        queue = _client.queues.create(friendly_name: friendly_name)
        adapter_alert.meta["live_call_queue_sid"] = queue.sid
        adapter_alert.save!

        _twiml.enqueue(
          name: friendly_name,
          action: PagerTree::Integrations::Engine.routes.url_helpers.queue_status_live_call_routing_twilio_v3_path(id, thirdparty_id: _thirdparty_id),
          method: "POST",
          wait_url: PagerTree::Integrations::Engine.routes.url_helpers.music_live_call_routing_twilio_v3_path(id, thirdparty_id: _thirdparty_id),
          wait_url_method: "GET"
        )
      else
        adapter_alert.meta["live_call_repeat_count"] ||= 0
        adapter_alert.meta["live_call_repeat_count"] += 1
        adapter_alert.save!

        if adapter_alert.meta["live_call_repeat_count"] <= 3
          adapter_alert.logs.create!(message: "Caller has not selected a team. Playing team options.")
          _twiml.gather numDigits: _teams_size.to_s.size, timeout: 30 do |g|
            3.times do
              g.say(message: _teams_message, **SPEAK_OPTIONS)
              g.pause(length: 1)
            end
          end
        else
          adapter_alert.logs.create!(message: "Caller input bad input (too many times). Hangup.")
          _twiml.say(message: "Too much invalid input. Goodbye.", **SPEAK_OPTIONS)
          _twiml.hangup
        end
      end

      adapter_controller&.render(xml: _twiml.to_xml)
    end

    def adapter_response_disabled
      _twiml.say(message: "This integration is currently disabled. Goodbye!", **SPEAK_OPTIONS)
      _twiml.hangup

      adapter_controller&.render(xml: _twiml.to_xml)
    end

    def adapter_response_upgrade
      _twiml.say(message: "This account must be upgraded to use live call routing. Goodbye!", **SPEAK_OPTIONS)
      _twiml.hangup

      adapter_controller&.render(xml: _twiml.to_xml)
    end

    def adapter_response_maintenance_mode
      _twiml.say(message: "This integration is currently in maintenance mode. Goodbye!", **SPEAK_OPTIONS)
      _twiml.hangup

      adapter_controller&.render(xml: _twiml.to_xml)
    end

    def adapter_response_music
      _twiml.play(url: option_music_media_url, loop: 0)
      adapter_controller&.render(xml: _twiml.to_xml)
    end

    def response_dropped
      recording_url = adapter_incoming_request_params.dig("RecordingUrl")

      if recording_url
        if option_no_answer_thank_you_media.present?
          _twiml.play(url: option_no_answer_thank_you_media.url)
        else
          _twiml.say(message: "Thank you for your message. Goodbye.")
        end
        _twiml.hangup

        adapter_alert.additional_data.push(AdditionalDatum.new(format: "link", label: "Voicemail", value: recording_url).to_h)
        adapter_alert.save!

        adapter_alert.logs.create!(message: "Caller left a <a href='#{recording_url}' target='_blank'>voicemail</a>.")

        adapter_record_emails.each do |email|
          TwilioLiveCallRouting::V3Mailer.with(email: email, alert: alert).call_recording.deliver_later
        end
      elsif record
        _twiml.play(url: option_no_answer_media_url)
        _twiml.record(max_length: 60)
      else
        _twiml.say(message: "No one is available to answer this call. Goodbye.")
        _twiml.hangup
      end

      controller.render(xml: _twiml.to_xml)
    end

    def adapter_process_queue_status_deferred
      queue_result = adapter_incoming_request_params.dig("QueueResult")
      adapter_source_log&.sublog("Processing queus status #{queue_result}")

      if queue_result == "hangup"
        self.adapter_alert = alerts.find_by(thirdparty_id: _thirdparty_id)
        queue_destroy
      end

      adapter_source_log&.save!
    end

    def perform_outgoing(**params)
      event = params[:event]
      if event == "alert.acknowledged"
        on_acknowledge
      elsif event == "alert.dropped"
        on_drop
      end
    end

    private

    def _thirdparty_id
      adapter_incoming_request_params.dig("CallSid")
    end

    def _title
      "Incoming call from #{adapter_incoming_request_params.dig("From")}"
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "phone", label: "Caller Phone", value: adapter_incoming_request_params.dig("From")),
        AdditionalDatum.new(format: "text", label: "Caller City", value: adapter_incoming_request_params.dig("CallerCity")),
        AdditionalDatum.new(format: "text", label: "Caller State", value: adapter_incoming_request_params.dig("CallerState")),
        AdditionalDatum.new(format: "text", label: "Caller Zipcode", value: adapter_incoming_request_params.dig("CallerZipcode")),
        AdditionalDatum.new(format: "text", label: "Caller Country", value: adapter_incoming_request_params.dig("CallerCountry"))
      ]
    end

    def _client
      @_client ||= ::Twilio::REST::Client.new(self.option_api_key, self.option_api_secret, self.option_account_sid)
    end

    def _call
      @_call ||= _client.calls(call_sid).fetch
    end

    def _twiml
      @_twiml ||= ::Twilio::TwiML::VoiceResponse.new
    end

    def _teams_size
      @_teams_size ||= teams.size
    end

    def _teams_sorted
      @_teams_sorted ||= teams.order(name: :desc)
    end

    def _teams_message
      "Make a selection followed by the pound sign. " + _teams_sorted.each_with_index.map { |team, index| "#{index + 1} for #{team.name}." }.join(" ")
    end

    def _digits
      @_digits ||= adapter_incoming_request_params.dig("Digits")&.to_i
    end

    def selected_team
      return nil if _teams_size == 0
      return _teams_sorted.first if _teams_size == 1 && option_force_input == false
      return _teams_sorted[_digits - 1] if _digits.present?
      nil
    end

    def on_acknowledge
      # log that we are going to transfer
      adapter_alert.logs.create!(message: "Attempting to transfer the call...")

      # try to transfer the caller
      number = "+19402733696"
      _twiml.play(url: option_connect_now_media_url)
      _twiml.pause(length: 1)
      _twiml.dial(number: number, caller_id: _call.to, answer_on_bridge: true)
      _call.update(twiml: _twiml.to_xml)

      # log if we successfully transfered or failed
      adapter_alert.logs.create!(message: "Tranferring the call succeeded.")
    end

    def on_drop
      _call.update(url: PagerTree::Integrations::Engine.routes.url_helpers.dropped_twilio_live_call_routing_v3_url(id, thirdparty_id: thirdparty_id))
    end

    def queue_destroy
      if (queue_sid = adapter_alert&.meta&.fetch("live_call_queue_sid", nil))
        begin
          _client.queues(queue_sid).delete
          adapter_source_log&.sublog("Successfully destroyed queue")
        rescue => exception
          adapter_source_log&.sublog("Failed to destroy queue - #{exception.message}")
        end
      end
    end
  end
end
