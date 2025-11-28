module PagerTree::Integrations
  class Crowdstrike::V3 < Integration
    OPTIONS = [
      {key: :hmac_secret, type: :password, default: nil},
      {key: :capture_additional_data, type: :boolean, default: false}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"
    
    validates :option_hmac_secret, format: {with: /\A.{0,256}\z/}, allow_nil: true

    after_initialize do
      self.option_hmac_secret ||= nil
      self.option_capture_additional_data ||= false
    end
    
    def adapter_should_block_incoming?(request)
      if option_hmac_secret.present?
        timestamp = request.headers["x-cs-delivery-timestamp"]
        signature = request.headers["x-cs-primary-signature"]
        algorithm = request.headers["x-cs-signature-algorithm"] || "hmac-sha256"

        return true if timestamp.blank? || signature.blank?

        raw_body = request.body.read
        message = "#{timestamp}#{raw_body}"
        computed_signature = OpenSSL::HMAC.hexdigest("SHA256", option_hmac_secret, message)

        unless ActiveSupport::SecurityUtils.secure_compare(computed_signature, signature)
          return true
        end
      end

      false
    end

    def adapter_supports_incoming?
      true
    end

    def adapter_supports_outgoing?
      false
    end

    def adapter_incoming_can_defer?
      true
    end

    def adapter_thirdparty_id
      @adapter_thirdparty_id ||= _data.dig("id") || SecureRandom.uuid
    end

    def adapter_action
      case _data.dig("event_type").to_s.downcase.strip
      when "create"
        :create
      when "acknowledge"
        :acknowledge
      when "resolve"
        :resolve
      else
        :other
      end
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        description: _description,
        urgency: _urgency,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: _dedup_keys,
        incident: _incident,
        incident_severity: _incident_severity,
        incident_message: _incident_message,
        tags: _tags,
        meta: _meta,
        additional_data: _additional_datums
      )
    end

    private

    def _adapter_incoming_request_params
      adapter_incoming_request_params.transform_keys(&:downcase)
    end
    
    def _data
      _adapter_incoming_request_params.dig("data")
    end

    def _meta
      _adapter_incoming_request_params.dig("meta")
    end

    def _title
      _data.dig("title")
    end

    def _description
      _data.dig("description")
    end

    def _tags
      tags = _data.dig("tags")
      Array(tags).compact_blank.map(&:to_s).uniq
    end

    def _urgency
      text = _data.dig("urgency")
      matches = /(?<urgency>low|medium|high|critical)/.match(text&.to_s&.downcase&.strip)
      matches ? matches[:urgency].to_s : nil
    end

    def _incident
      !!_data.dig("meta", "incident")
    end

    def _incident_message
      _data.dig("meta", "incident_message")
    end

    def _incident_severity
      _data.dig("meta", "incident_severity")&.to_s&.upcase&.strip
    end

    def _additional_datums
      if self.option_capture_additional_data == true
        _data.except(
          "id", "title", "description", "urgency", "tags", "meta", "event_type", "pagertree_integration_id", "dedup_keys"
        ).map do |key, value|
          AdditionalDatum.new(format: "text", label: key, value: value.to_s)
        end
      else
        []
      end
    end

    def _dedup_keys
      Array(_data.dig("dedup_keys")).map(&:to_s).compact_blank.uniq
    end

    
  end
end
