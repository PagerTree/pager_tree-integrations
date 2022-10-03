module PagerTree::Integrations
  class Email::V3 < Integration
    OPTIONS = [
      {key: :allow_spam, type: :boolean, default: false},
      {key: :dedup_threads, type: :boolean, default: true}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    validates :option_allow_spam, inclusion: {in: [true, false]}
    validates :option_dedup_threads, inclusion: {in: [true, false]}

    after_initialize do
      self.option_allow_spam = false if option_allow_spam.nil?
      self.option_dedup_threads = true if option_dedup_threads.nil?
    end

    # SPECIAL: override integration endpoint
    def endpoint
      domain = ::PagerTree::Integrations.integration_email_v3_domain
      inbox = ::PagerTree::Integrations.integration_email_v3_inbox
      postfix = ""
      postfix = "_stg" if Rails.env.staging?
      postfix = "_tst" if Rails.env.test?
      postfix = "_dev" if Rails.env.development?

      "#{inbox}#{postfix}+#{id}@#{domain}"
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
      :create
    end

    def adapter_process_create
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

    private

    def _mail
      @_mail ||= adapter_incoming_request_params.dig("mail")
    end

    def _inbound_email
      @_inbound_email ||= adapter_incoming_request_params.dig("inbound_email")
    end

    def _thirdparty_id
      _mail.message_id
    end

    def _dedup_keys
      keys = [_thirdparty_id]
      keys.concat(Array(_mail.references)) if option_dedup_threads
      keys
    end

    def _title
      _mail.subject
    end

    def _description
      _body
    end

    def _body
      return @_body if @_body

      if _mail.multipart? && _mail.html_part
        document = Nokogiri::HTML(_mail.html_part.body.decoded)

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

        @_body = ::Sanitize.document(document, Sanitize::Config::RELAXED)
      elsif _mail.multipart? && _mail.text_part
        @_body = _mail.text_part.body.decoded
      else
        @_body = _mail.decoded
      end

      @_body
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
      [
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
