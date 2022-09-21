module PagerTree::Integrations
  class Twilio::IncomingSms::V3 < Integration
    OPTIONS = []
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    after_initialize do
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
      adapter_incoming_request_params.dig("MessageSid")
    end

    def adapter_action
      :create
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        description: _description,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [],
        additional_data: _additional_datums
      )
    end

    private

    def _title
      "Incoming SMS from #{adapter_incoming_request_params.dig("From")} - See description for details"
    end

    def _description
      adapter_incoming_request_params.dig("Body")
    end

    def _additional_datums
      datums = [
        AdditionalDatum.new(format: "link", label: "Twilio URL", value: "https://www.twilio.com/console/sms/logs/#{adapter_incoming_request_params.dig("MessageSid")}"),
        AdditionalDatum.new(format: "text", label: "Account SID", value: adapter_incoming_request_params.dig("AccountSid")),
        AdditionalDatum.new(format: "text", label: "Message SID", value: adapter_incoming_request_params.dig("MessageSid")),
        AdditionalDatum.new(format: "phone", label: "To", value: adapter_incoming_request_params.dig("To")),
        AdditionalDatum.new(format: "phone", label: "From", value: adapter_incoming_request_params.dig("From")),
        AdditionalDatum.new(format: "text", label: "From Country", value: adapter_incoming_request_params.dig("FromCountry")),
        AdditionalDatum.new(format: "text", label: "From State", value: adapter_incoming_request_params.dig("FromState")),
        AdditionalDatum.new(format: "text", label: "From City", value: adapter_incoming_request_params.dig("FromCity")),
        AdditionalDatum.new(format: "text", label: "From Zip", value: adapter_incoming_request_params.dig("FromZip"))
      ]

      num_media = adapter_incoming_request_params.dig("NumMedia").to_i
      index = 0

      while index < num_media
        media_content_type = adapter_incoming_request_params.dig("MediaContentType#{index}")
        datums.push(AdditionalDatum.new(
          format: media_content_type.starts_with?("im") ? "img" : "link",
          label: "Media ##{index + 1}",
          value: adapter_incoming_request_params.dig("MediaUrl#{index}")
        ))
        index += 1
      end

      datums
    end
  end
end
