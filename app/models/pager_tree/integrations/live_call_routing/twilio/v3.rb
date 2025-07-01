module PagerTree::Integrations
  class LiveCallRouting::Twilio::V3 < Integration
    OPTIONS = [
      {key: :account_sid, type: :string, default: nil},
      {key: :api_key, type: :string, default: nil},
      {key: :api_secret, type: :string, default: nil},
      {key: :api_region, type: :string, default: "ashburn.us1"},
      {key: :force_input, type: :boolean, default: false},
      {key: :record, type: :boolean, default: false},
      {key: :record_email, type: :string, default: ""},
      {key: :banned_phone, type: :string, default: ""},
      {key: :dial_pause, type: :integer},
      {key: :max_wait_time, type: :integer, default: nil}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    API_REGIONS = ["ashburn.us1", "dublin.ie1", "sydney.au1"]

    has_one_attached :option_connect_now_media
    has_one_attached :option_music_media
    has_one_attached :option_no_answer_media
    has_one_attached :option_no_answer_thank_you_media
    has_one_attached :option_please_wait_media
    has_one_attached :option_welcome_media

    validates :option_account_sid, presence: true
    validates :option_api_key, presence: true
    validates :option_api_secret, presence: true
    validates :option_api_region, inclusion: {in: API_REGIONS}
    validates :option_force_input, inclusion: {in: [true, false]}
    validates :option_record, inclusion: {in: [true, false]}
    validates :option_max_wait_time, numericality: {greater_than_or_equal_to: 30, less_than_or_equal_to: 3600}, allow_nil: true
    validate :validate_record_emails

    after_initialize do
      self.option_account_sid ||= nil
      self.option_api_key ||= nil
      self.option_api_secret ||= nil
      self.option_api_region ||= "ashburn.us1"
      self.option_force_input ||= false
      self.option_record ||= false
      self.option_record_email ||= ""
      self.option_banned_phone ||= ""
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

    def option_banned_phones=(x)
      self.option_banned_phone = Array(x).join(",")
    end

    def option_banned_phones
      self.option_banned_phone.split(",")
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

    def option_banned_phones_list=(x)
      # what comes in as json, via tagify
      uniq_array = []
      begin
        uniq_array = JSON.parse(x).map { |y| y["value"] }.uniq
      rescue JSON::ParserError => exception
        Rails.logger.debug(exception)
      end

      self.option_banned_phones = uniq_array
    end

    def option_banned_phones_list
      option_banned_phones
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

    def adapter_supports_auto_aggregate?
      false
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

    def is_banned?
      from_number = adapter_incoming_request_params.dig("From")
      return false unless from_number.present?
      option_banned_phones.any? { |x| from_number.include?(x) }
    rescue
      false
    end

    def adapter_action
      if is_banned?
        :other
      else
        :create
      end
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
      if is_banned?
        _twiml.reject

        adapter_source_log&.sublog("Caller #{adapter_incoming_request_params.dig("From")} on blocked list. Rejected call.")
        adapter_source_log&.save

        return adapter_controller&.render(xml: _twiml.to_xml)
      end
      # if this was attached to a router
      if !adapter_alert.meta["live_call_router_team_prefix_ids"].present? && routers.size > 0 && account.subscription_feature_routers?
        adapter_alert.logs.create!(message: "Routed to router. Attempting to get a list of teams...")
        team_ids = []
        default_receiver_team_ids = []
        v3 = adapter_alert.v3_format
        routers.each do |router|
          if router.enabled? && router.kept?
            actions = router.rules_eval({
              always: true,
              alert: v3
            })

            actions.flatten!

            actions.each do |action|
              team_ids << Array(action["receiver"]) if action["type"] == "assign"
            end

            # hold on to the default destination team ids in case we need them later
            default_receiver_team_ids |= [router.default_receiver.prefix_id] if router.default_receiver.present?
          end
        end # end routers.each

        team_ids.flatten!
        team_ids.uniq!

        # if the router didn't return any teams, use the default receiver teams
        team_ids = default_receiver_team_ids if team_ids.size == 0

        if team_ids.size > 0
          adapter_alert.logs.create!(message: "Router provided #{team_ids.size} teams: #{team_ids}")
          adapter_alert.meta["live_call_router_team_prefix_ids"] = team_ids
          adapter_alert.save!
        else
          adapter_alert.logs.create!(message: "Router provided no teams.")
        end
      end # end if routers

      if _teams_size == 0
        adapter_alert.logs.create!(message: "This integration is not configured to route to any teams. Hang up.")
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

        if option_max_wait_time.present?
          # set the max wait time for the queue
          PagerTree::Integrations::LiveCallRouting::Twilio::V3::MaxWaitTimeJob.set(wait: option_max_wait_time.seconds).perform_later(id, adapter_alert.id)
          adapter_alert.logs.create!(message: "Max wait time set to #{option_max_wait_time} seconds.")
        end
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
          adapter_alert.logs.create!(message: "Caller input: bad input (too many times). Hangup.")
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

        adapter_alert.logs.create!(message: "Caller left a voicemail.")

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

          adapter_alert.logs.create!(message: "Sending voicemail recording to #{emails.size} emails.")
          emails.each do |email|
            LiveCallRouting::Twilio::V3Mailer.with(email: email, alert: adapter_alert, from: adapter_incoming_request_params.dig("From"), recording_url: recording_url).call_recording.deliver_later
          end
        end
      elsif option_record
        adapter_alert.logs.create!(message: "No one is available to answer this call. Requesting voicemail recording.")
        _twiml.play(url: option_no_answer_media_url)
        _twiml.record(max_length: 60)
      else
        adapter_alert.logs.create!(message: "No one is available to answer this call. Hangup on caller.")
        _twiml.say(message: "No one is available to answer this call. Goodbye.", **SPEAK_OPTIONS)
        _twiml.hangup
      end

      adapter_controller.render(xml: _twiml.to_xml)
    end

    def adapter_process_queue_status_deferred
      queue_result = adapter_incoming_request_params.dig("QueueResult")
      adapter_source_log&.sublog("Processing queue status #{queue_result}")

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

    def max_wait_time_reached!(alert_id)
      # Handle max wait time reached logic
      self.adapter_alert = alerts.find(alert_id)
      return unless adapter_alert&.status_open?

      _on_max_wait_time_reached
    end

    private

    def _thirdparty_id
      adapter_incoming_request_params.dig("CallSid")
    end

    def _title
      "Incoming call from #{adapter_incoming_request_params.dig("From")&.split("")&.join(" ")}"
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

    def _api_region
      API_REGIONS.include?(option_api_region) ? option_api_region : "ashburn.us1"
    end

    def _client
      @_client ||= ::Twilio::REST::Client.new(self.option_api_key, self.option_api_secret, self.option_account_sid, _api_region)
    end

    def _call
      @_call ||= _client.calls(adapter_alert.thirdparty_id).fetch
    end

    def _twiml
      @_twiml ||= ::Twilio::TwiML::VoiceResponse.new
    end

    def _teams
      @_teams ||= adapter_alert.meta["live_call_router_team_prefix_ids"].present? ? Team.where(account_id: account_id, prefix_id: adapter_alert.meta["live_call_router_team_prefix_ids"]) : teams
    end

    def _teams_size
      @_teams_size ||= _teams.size
    end

    def _teams_sorted
      @_teams_sorted ||= adapter_alert.meta["live_call_router_team_prefix_ids"].present? ?
        # sorts by the order the user gave us in the router
        _teams.sort_by { |t| adapter_alert.meta["live_call_router_team_prefix_ids"].index(t.prefix_id) } :
        # sorts in alpha order (not ascii, but dictionary style order)
        _teams.order(name: :asc)
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
        _twiml.pause(length: option_dial_pause.to_i.clamp(1, 15))
        _twiml.dial(number: number, caller_id: _call.to, answer_on_bridge: true)
        _call.update(twiml: _twiml.to_xml)
        # log if we successfully transfered or failed
        adapter_alert.logs.create!(message: "Transferring the call succeeded.")
      else
        _twiml.say(message: "Someone has acknowledged this call, but they do not have a phone number on file. Goodbye.")
        _twiml.hangup
        _call.update(twiml: _twiml.to_xml)
        adapter_alert.logs.create!(message: "Transferring the call failed. #{account_user.user.name} has no phone number on file.")
      end
    rescue ::Twilio::REST::RestError => e
      if e.code == 21220
        # 21220 - Unable to update record. Call is not in-progress. Cannot redirect.
        adapter_alert.logs.create!(message: "[on_acknowledge] Transferring the call failed. The caller has already hung up.")
      else
        adapter_alert.logs.create!(message: "[on_acknowledge] Transferring the call failed. #{e.message}")
      end
    end

    def _on_drop
      # log that we are going to transer
      adapter_alert.logs.create!(message: "The alert was dropped. Attempting to transfer the call...")
      _call.update(url: PagerTree::Integrations::Engine.routes.url_helpers.dropped_live_call_routing_twilio_v3_url(id, thirdparty_id: adapter_alert.thirdparty_id))
      adapter_alert.logs.create!(message: "Transferring the call succeeded.")
    rescue ::Twilio::REST::RestError => e
      if e.code == 21220
        # 21220 - Unable to update record. Call is not in-progress. Cannot redirect
        adapter_alert.logs.create!(message: "[on_drop] Transferring the call failed. The caller has already hung up.")
      else
        adapter_alert.logs.create!(message: "[on_drop] Transferring the call failed. #{e.message}")
      end
    end

    def _on_max_wait_time_reached
      # log that we are going to transfer
      adapter_alert.logs.create!(message: "The max wait time was reached. Attempting to transfer the caller (via max wait time, to voicemail or hangup)...")
      _call.update(url: PagerTree::Integrations::Engine.routes.url_helpers.dropped_live_call_routing_twilio_v3_url(id, thirdparty_id: adapter_alert.thirdparty_id))
      adapter_alert.logs.create!(message: "Transferring the caller (via max wait time, to voicemail or hangup) succeeded.")
    rescue ::Twilio::REST::RestError => e
      adapter_alert.logs.create!(message: "Transferring the caller (via max wait time, to voicemail or hangup) failed. #{e.message}")
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
