module PagerTree::Integrations
  class Email::V3 < Integration
    extend ::PagerTree::Integrations::Env

    # the source log (if created) - Its what shows on the integration page (different from deferred request)
    attribute :adapter_source_log

    OPTIONS = [
      {key: :allow_spam, type: :boolean, default: false},
      {key: :dedup_threads, type: :boolean, default: true},
      {key: :sanitize_level, type: :string, default: "relaxed"},
      {key: :custom_definition, type: :string, default: nil},
      {key: :custom_definition_enabled, type: :boolean, default: false}
    ]

    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    SANITIZE_LEVELS = ["basic", "default", "relaxed", "relaxed_2", "restricted"]

    validates :option_allow_spam, inclusion: {in: [true, false]}
    validates :option_dedup_threads, inclusion: {in: [true, false]}
    validates :option_sanitize_level, inclusion: {in: SANITIZE_LEVELS}

    def self.custom_webhook_v3_service_url
      ::PagerTree::Integrations.integration_custom_webhook_v3_service_url.presence ||
        find_value_by_name("integration_custom_webhook_v3", "service_url")
    end

    after_initialize do
      self.option_allow_spam = false if option_allow_spam.nil?
      self.option_dedup_threads = true if option_dedup_threads.nil?
      self.option_sanitize_level = "relaxed" if option_sanitize_level.nil?
      self.option_custom_definition_enabled = false if option_custom_definition_enabled.nil?
    end

    # SPECIAL: override integration endpoint
    def endpoint
      domain = ::PagerTree::Integrations.integration_email_v3_domain
      inbox = ::PagerTree::Integrations.integration_email_v3_inbox
      postfix = ""
      postfix = "_stg" if Rails.env.staging?
      postfix = "_tst" if Rails.env.test?
      postfix = "_dev" if Rails.env.development?

      if Rails.env.production?
        if created_at&.after?(DateTime.parse("2023-09-01"))
          # new emails
          # int_abc123@domain.com
          "#{v == 3 ? prefix_id : id}@#{domain}"
        else
          # legacy emails
          # a+int_abc123@domain.com
          "#{inbox}#{postfix}+#{v == 3 ? prefix_id : id}@#{domain}"
        end
      else
        # staging, test, development
        "#{inbox}#{postfix}+#{v == 3 ? prefix_id : id}@#{domain}"
      end
    end

    def custom_definition?
      option_custom_definition_enabled && option_custom_definition.present?
    end

    def adapter_should_block?
      return false if option_allow_spam == true

      ses_spam_verdict = _get_header("X-SES-Spam-Verdict")&.value

      if ses_spam_verdict.present?
        return ses_spam_verdict != "PASS"
      end

      false
    end

    def adapter_supports_incoming?
      true
    end

    def adapter_thirdparty_id
      _thirdparty_id
    end

    def adapter_action
      if custom_definition?
        case custom_response_result.dig("type")&.downcase
        when "create"
          :create
        when "acknowledge"
          :acknowledge
        when "resolve"
          :resolve
        else
          :other
        end
      else
        :create
      end
    end

    def adapter_process_create
      if custom_definition?
        Alert.new(
          title: _title,
          description: _description,
          urgency: _urgency,
          thirdparty_id: _thirdparty_id,
          dedup_keys: _dedup_keys,
          incident: _incident,
          incident_severity: _incident_severity,
          incident_message: _incident_message,
          tags: _tags,
          meta: _meta,
          additional_data: _additional_datums,
          attachments: _attachments
        )
      else
        Alert.new(
          title: _title,
          description: _description,
          urgency: urgency,
          thirdparty_id: _thirdparty_id,
          dedup_keys: _dedup_keys,
          additional_data: _additional_datums,
          attachments: _attachments
        )
      end
    end

    private

    def _custom_response
      return @_custom_response ||= {} unless custom_definition?

      @_custom_response ||= begin
        log_hash = {
          subject: _mail.subject,
          body: _body,
          from: _mail.from,
          to: _mail.to
        }

        body_hash = {
          log: log_hash,
          config: JSON.parse(PagerTree::Integrations::FormatConverters::YamlJsonConverter.convert_to_json(option_custom_definition))
        }

        response = HTTParty.post(
          self.class.custom_webhook_v3_service_url,
          body: body_hash.to_json,
          headers: {"Content-Type" => "application/json"},
          timeout: 2
        )

        unless response.success?
          if response.parsed_response.dig("error").present?
            adapter_source_log&.sublog({
              message: "Custom Webhook Service Error:",
              parsed_response: response.parsed_response
            })
            adapter_source_log&.save
          end
          raise "Custom Webhook Service HTTP error: #{response.code} - #{response.message} - #{response.body}"
        end

        adapter_source_log&.sublog({
          message: "Custom Webhook Service Response:",
          parsed_response: response.parsed_response
        })
        adapter_source_log&.save

        response.parsed_response
      rescue JSON::ParserError => e
        Rails.logger.error("Custom Webhook YAML to JSON conversion error: #{e.message}")
        adapter_source_log&.sublog("Custom Webhook YAML to JSON conversion error: #{e.message}")
        adapter_source_log&.save
        raise "Invalid YAML configuration: #{e.message}"
      rescue HTTParty::Error, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
        Rails.logger.error("Custom Webhook Service error: #{e.message}")
        adapter_source_log&.sublog("Custom Webhook Service error: #{e.message}")
        adapter_source_log&.save
        raise "Custom Webhook Service error: #{e.message}"
      rescue => e
        Rails.logger.error("Unexpected error in Custom Webhook: #{e.message}")
        adapter_source_log&.sublog("Unexpected error in Custom Webhook: #{e.message}")
        adapter_source_log&.save
        raise e
      end
    end

    def _custom_response_status
      @_custom_response_status ||= _custom_response.dig("status")
    end

    def custom_response_result
      @_custom_response_result ||= _custom_response.dig("results")&.first || {}
    end

    def _mail
      @_mail ||= adapter_incoming_request_params.dig("mail")
    end

    def _inbound_email
      @_inbound_email ||= adapter_incoming_request_params.dig("inbound_email")
    end

    def _thirdparty_id
      if custom_definition?
        @_thirdparty_id ||= custom_response_result.dig("thirdparty_id").to_s.presence
      end

      @_thirdparty_id ||= _mail.message_id || SecureRandom.uuid
    end

    def _dedup_keys
      return @_dedup_keys if @_dedup_keys

      @_dedup_keys ||= []

      if option_dedup_threads
        @_dedup_keys.concat(Array(_thirdparty_id))
        @_dedup_keys.concat(Array(_mail.references))
      end

      if custom_definition?
        @_dedup_keys.concat(Array(custom_response_result.dig("dedup_keys")))
      end

      # only dedup the references per integration. Customer like sending one email to multiple integration inboxes
      @_dedup_keys = @_dedup_keys.compact_blank.uniq.map { |x| "#{prefix_id}_#{x}" }
    end

    def _title
      if custom_definition?
        @_title ||= custom_response_result.dig("title")&.to_s&.presence
      end

      @_title ||= _mail.subject.to_s.presence || "Incoming Email - Untitled Alert"
    end

    def _description
      if custom_definition?
        @_description ||= custom_response_result.dig("description")&.to_s&.presence
      end

      @_description ||= _body.to_s
    end

    def _urgency
      if custom_definition?
        @_urgency ||= custom_response_result.dig("urgency")&.to_s&.presence
      end

      @_urgency ||= urgency
    end

    def _incident
      @_incident ||= ActiveModel::Type::Boolean.new.cast(custom_response_result.dig("incident"))
    end

    def _incident_severity
      custom_response_result.dig("incident_severity")&.to_s&.presence
    end

    def _incident_message
      custom_response_result.dig("incident_message")&.to_s&.presence
    end

    def _tags
      tags = custom_response_result.dig("tags")
      tags = tags.split(",") if tags.is_a?(String)
      Array(tags).compact_blank.map(&:to_s).uniq
    end

    def _meta
      meta = custom_response_result.dig("meta")
      meta.is_a?(Hash) ? meta : {}
    end

    def _body
      return @_body if @_body

      if _mail.multipart? && _mail.html_part
        document = Nokogiri::HTML(_mail_body_part_to_utf8(_mail.html_part))

        _attachments_hash.map do |attachment_hash|
          attachment = attachment_hash[:original]
          blob = attachment_hash[:blob]

          if attachment.content_id.present?
            # Remove the beginning and end < >
            content_id = attachment.content_id[1...-1]
            element = document.at_css "img[src='cid:#{content_id}']"

            element&.replace "<action-text-attachment sgid=\"#{blob.attachable_sgid}\" content-type=\"#{attachment.content_type}\" filename=\"#{attachment.filename}\"></action-text-attachment>"
          end
        end

        @_body = custom_definition? ?
          (document.at_css("body")&.inner_html || document.to_html) :
          ::Sanitize.fragment(document, _sanitize_config)
      elsif _mail.multipart? && _mail.text_part
        @_body = _mail_body_part_to_utf8(_mail.text_part)
      else
        @_body = _mail.decoded
      end

      @_body
    end

    def _sanitize_config
      case option_sanitize_level
      when "basic" then Sanitize::Config::BASIC
      when "default" then Sanitize::Config::DEFAULT
      when "relaxed" then Sanitize::Config::RELAXED
      when "restricted" then Sanitize::Config::RESTRICTED
      when "relaxed_2"
        Sanitize::Config.merge(Sanitize::Config::RELAXED, elements: Sanitize::Config::RELAXED[:elements].excluding("style"))
      end
    end

    # Encodings can cause lots of issues, so we try to convert to UTF-8
    # https://github.com/mikel/mail#encodings
    # https://stackoverflow.com/a/15818886/2903189
    def _mail_body_part_to_utf8(part_to_use)
      # get the message body without the header information
      body = part_to_use.body.decoded

      if body.encoding.name != "UTF-8"
        # readout the encoding (charset) of the part
        encoding = part_to_use.content_type_parameters["charset"] if part_to_use.content_type_parameters

        # and convert it to UTF-8
        if encoding
          body = body.force_encoding(encoding).encode("UTF-8")
        else
          raise StandardError.new "Unknown encoding for mail body part"
        end
      end

      # return the body
      body
    rescue
      # if something goes wrong, just return the original body with characters replaced
      body.encode("UTF-8", "binary", invalid: :replace, undef: :replace, replace: "?")
    end

    def _attachments_hash
      @_attachments_hash ||= _mail.attachments.map do |attachment|
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new(attachment.body.to_s),
          filename: attachment.filename,
          content_type: attachment.content_type
        )
        {original: attachment, blob: blob}
      end
    end

    def _attachments
      _attachments_hash.map { |attachment_hash| attachment_hash[:blob] }
    end

    # TODO: Implement any additional data that should be shown in the alert with high priority (be picky as to 'very important' information)
    def _additional_datums
      return @_additional_datums if @_additional_datums

      if custom_definition?
        @_additional_datums ||= begin
          items = custom_response_result.dig("additional_data") || []
          items = [items] unless items.is_a?(Array)

          items.each_with_object([]) do |ad, result|
            next unless ad.is_a?(Hash)

            format = ad["format"].to_s
            next unless PagerTree::Integrations::AdditionalDatum::FORMATS.include?(format)

            result << AdditionalDatum.new(
              format: format,
              label: ad["label"].to_s.presence || "Untitled",
              value: ad["value"]
            )
          end
        end
      end

      @_additional_datums ||= [
        AdditionalDatum.new(format: "email", label: "From", value: _mail.from),
        AdditionalDatum.new(format: "email", label: "To", value: _mail.to),
        AdditionalDatum.new(format: "email", label: "CCs", value: _mail.cc)
      ]
    end

    def _get_header(name)
      _mail.header_fields.find { |x| x.name == name }
    end
  end
end
