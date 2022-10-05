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

    def option_connect_now_media_url
      option_connect_now_media.present? ? option_connect_now_media.url : URI.join(Rails.application.routes.url_helpers.root_url, "audios/you-are-now-being-connected.mp3").to_s
    end

    def option_music_media_url
      option_music_media.present? ? option_music_media.url : "http://com.twilio.sounds.music.s3.amazonaws.com/oldDog_-_endless_goodbye_%28instr.%29.mp3"
    end

    def option_please_wait_media_url
      option_please_wait_media.present? ? option_please_wait_media.url : URI.join(Rails.application.routes.url_helpers.root_url, "audios/please-wait.mp3").to_s
    end

    def option_no_answer_media_url
      option_no_answer_media.present? ? option_no_answer_media.url : URI.join(Rails.application.routes.url_helpers.root_url, "audios/no-answer.mp3").to_s
    end

    def option_no_answer_thank_you_media_url
      option_no_answer_thank_you_media.present? ? option_no_answer_thank_you_media.url : URI.join(Rails.application.routes.url_helpers.root_url, "audios/thanks-for-message.mp3").to_s
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
      errors.add(:record_emails, "must be a valid email") if option_record_emails.any? { |x| !(x.match(URI::MailTo::EMAIL_REGEXP) || ["team", "team-admin", "on-call"].include?(x)) }
    end

    def adapter_supports_incoming?
      true
    end

    def adapter_supports_outgoing?
      true
    end

    def adapter_outgoing_interest?(event_name)
      ["alert_acknowledged", "alert_dropped"].include?(event_name) && adapter_alert.source_id == id
    end

    def adapter_incoming_can_defer?
      false
    end

    def adapter_will_route_alert?
      true
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
        dedup_keys: [],
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
        adapter_alert.logs.create!(message: "Caller selected team '#{selected_team.name}'.") if _teams_size > 1 || option_force_input

        adapter_alert.logs.create!(message: "Play please wait media to caller.")
        _twiml.play(url: option_please_wait_media_url)
        friendly_name = adapter_alert.id

        # create the queue and save it off
        queue = _client.queues.create(friendly_name: friendly_name)
        adapter_alert.meta["live_call_queue_sid"] = queue.sid

        adapter_alert.destination_teams = [selected_team]

        # save the alert
        adapter_alert.save!

        _twiml.enqueue(
          name: friendly_name,
          action: PagerTree::Integrations::Engine.routes.url_helpers.queue_status_live_call_routing_twilio_v3_path(id, thirdparty_id: _thirdparty_id),
          method: "POST",
          wait_url: PagerTree::Integrations::Engine.routes.url_helpers.music_live_call_routing_twilio_v3_path(id, thirdparty_id: _thirdparty_id),
          wait_url_method: "GET"
        )
        adapter_alert.logs.create!(message: "Enqueue caller in Twilio queue '#{friendly_name}'.")

        # kick off the alert workflow
        adapter_alert.route_later
        adapter_alert.logs.create!(message: "Successfully enqueued alert team workflow.")
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
          adapter_alert.resolve!(self)
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

    def adapter_response_dropped
      recording_url = adapter_incoming_request_params.dig("RecordingUrl")

      if recording_url
        _twiml.play(url: option_no_answer_thank_you_media_url)
        _twiml.hangup

        adapter_alert.additional_data.push(AdditionalDatum.new(format: "link", label: "Voicemail", value: recording_url).to_h)
        adapter_alert.save!

        adapter_alert.logs.create!(message: "Caller left a <a href='#{recording_url}' target='_blank'>voicemail</a>.")

        if option_record_emails.any?
          emails = option_record_emails.map do |x|
            if x == "team"
              Array(adapter_alert.destination_teams.map(&:admin_users).flatten&.map(&:email)) + Array(adapter_alert.destination_teams.map(&:member_users).flatten&.map(&:email))
            elsif x == "team-admin"
              Array(adapter_alert.destination_teams.map(&:admin_users).flatten&.map(&:email))
            elsif x == "on-call"
              adapter_alert.destination_teams.map do |t|
                Array(t.schedule.current_oncall_event_occurrences.map(&:attendees).flatten.map(&:attendee).uniq.map(&:email))
              end
            else
              x
            end
          end.flatten.compact_blank.uniq

          emails.each do |email|
            LiveCallRouting::Twilio::V3Mailer.with(email: email, alert: adapter_alert, from: adapter_incoming_request_params.dig("From"), recording_url: recording_url).call_recording.deliver_later
          end
        end
      elsif option_record
        _twiml.play(url: option_no_answer_media_url)
        _twiml.record(max_length: 60)
      else
        _twiml.say(message: "No one is available to answer this call. Goodbye.", **SPEAK_OPTIONS)
        _twiml.hangup
      end

      adapter_controller.render(xml: _twiml.to_xml)
    end

    def adapter_process_queue_status_deferred
      queue_result = adapter_incoming_request_params.dig("QueueResult")
      adapter_source_log&.sublog("Processing queus status #{queue_result}")

      if queue_result == "hangup"
        self.adapter_alert = alerts.find_by(thirdparty_id: _thirdparty_id)
        adapter_alert.logs.create!(message: "Caller hungup while waiting in queue.")
        adapter_alert.resolve!(self)
        queue_destroy
      end

      adapter_source_log&.save!
    end

    def adapter_process_outgoing
      event = adapter_outgoing_event.event_name.to_s
      if event == "alert_acknowledged"
        _on_acknowledge
      elsif event == "alert_dropped"
        _on_drop
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
      @_call ||= _client.calls(adapter_alert.thirdparty_id).fetch
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

    def _on_acknowledge
      # log that we are going to transfer
      adapter_alert.logs.create!(message: "The alert was acknowledged. Attempting to transfer the call...")

      # try to transfer the caller
      account_user = adapter_outgoing_event.account_user
      number = account_user.user.phone&.phone

      adapter_alert.logs.create!(message: "Attempting to transfer the call to #{account_user.user.name} at #{number}...")

      if number.present?
        _twiml.play(url: option_connect_now_media_url)
        _twiml.pause(length: 1)
        _twiml.dial(number: number, caller_id: _call.to, answer_on_bridge: true)
        _call.update(twiml: _twiml.to_xml)
        # log if we successfully transfered or failed
        adapter_alert.logs.create!(message: "Tranferring the call succeeded.")
      else
        _twiml.say(message: "Someone has acknowledged this call, but they do not have a phone number on file. Goodbye.")
        _twiml.hangup
        _call.update(twiml: _twiml.to_xml)
        adapter_alert.logs.create!(message: "Tranferring the call failed. #{account_user.user.name} has no phone number on file.")
      end
    rescue ::Twilio::REST::RestError => e
      # 21220 - Unable to update record. Call is not in-progress. Cannot redirect.
      if e.code != 21220
        adapter_alert.logs.create!(message: "Tranferring the call failed. #{e.message}")
      end
    end

    def _on_drop
      # log that we are going to transer
      adapter_alert.logs.create!(message: "The alert was dropped. Attempting to transfer the call...")
      _call.update(url: PagerTree::Integrations::Engine.routes.url_helpers.dropped_live_call_routing_twilio_v3_url(id, thirdparty_id: adapter_alert.thirdparty_id))
      music_live_call_routing_twilio_v3_path
      adapter_alert.logs.create!(message: "Tranferring the call succeeded.")
    rescue ::Twilio::REST::RestError => e
      adapter_alert.logs.create!(message: "Tranferring the call failed. #{e.message}")
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
