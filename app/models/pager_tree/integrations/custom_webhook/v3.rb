module PagerTree::Integrations
  class CustomWebhook::V3 < Integration
    extend ::PagerTree::Integrations::Env

    # the source log (if created) - Its what shows on the integration page (different from deferred request)
    attribute :adapter_source_log

    OPTIONS = [
      {key: :custom_definition, type: :string, default: nil}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    validates :option_custom_definition, presence: true

    def self.custom_webhook_v3_service_url
      ::PagerTree::Integrations.integration_custom_webhook_v3_service_url.presence ||
        find_value_by_name("integration_custom_webhook_v3", "service_url")
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
      custom_response_result.dig("thirdparty_id")
    end

    def adapter_action
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

    def custom_response_processed_log_data
      _custom_response_processed_log_data || {}
    end

    private

    def _custom_response
      return {} unless adapter_incoming_deferred_request.present?

      @_custom_response ||= begin
        log_hash = {
          remote_ip: adapter_incoming_deferred_request.remote_ip,
          url: adapter_incoming_deferred_request.url,
          method: adapter_incoming_deferred_request.method,
          headers: adapter_incoming_deferred_request.headers,
          data: adapter_incoming_deferred_request.params.presence || adapter_incoming_deferred_request.body,
          params: adapter_incoming_deferred_request.params,
          body: adapter_incoming_deferred_request.body
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
        raise "Custom Webhook Service error #{e.message}"
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

    def _custom_response_processed_log_data
      @_custom_response_processed_log_data ||= _custom_response.dig("processedLogData")
    end

    def _title
      custom_response_result.dig("title")&.to_s&.presence || "Untitled Alert"
    end

    def _description
      custom_response_result.dig("description")&.to_s || ""
    end

    def _urgency
      custom_response_result.dig("urgency")&.to_s&.presence
    end

    def _dedup_keys
      keys = custom_response_result.dig("dedup_keys")
      keys = keys.split(",") if keys.is_a?(String)
      Array(keys).compact_blank.map(&:to_s).uniq
    end

    def _incident
      ActiveModel::Type::Boolean.new.cast(custom_response_result.dig("incident"))
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

    def _additional_datums
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
  end
end
