module PagerTree::Integrations
  class CustomWebhook::V3 < Integration
    extend ::PagerTree::Integrations::Env

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

    private

    def _custom_response
      @_custom_response ||= begin
        log_hash = {
          url: adapter_incoming_deferred_request.url,
          method: adapter_incoming_deferred_request.method,
          headers: adapter_incoming_deferred_request.headers,
          data: adapter_incoming_deferred_request.body,
          remote_ip: adapter_incoming_deferred_request.remote_ip
        }

        response = HTTParty.post(
          self.class.custom_webhook_v3_service_url,
          body: {
            log: log_hash,
            config: option_custom_definition
          }.to_json,
          headers: {"Content-Type" => "application/json"},
          timeout: 2
        )

        unless response.success?
          if response.parsed_response.dig("error").present?
            adapter_source_log&.sublog("Custom Webhook Service Error: #{response.parsed_response.dig("error")}")
            adapter_source_log&.save
          end
          raise "HTTP error: #{response.code} - #{response.message} - #{response.body}"
        end

        adapter_source_log&.sublog("Custom Webhook Service Response: #{response.parsed_response}")
        adapter_source_log&.save

        response.parsed_response
      rescue HTTParty::Error, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
        Rails.logger.error("CustomWebhook service error: #{e.message}")
        raise "Failed to call custom webhook service: #{e.message}"
      end
    end

    def _custom_response_status
      @_custom_response_status ||= _custom_response.dig("status")
    end

    def custom_response_result
      @_custom_response_result ||= _custom_response.dig("results")&.first || {}
    end

    def _title
      custom_response_result.dig("title")
    end

    def _description
      custom_response_result.dig("description")
    end

    def _urgency
      custom_response_result.dig("urgency")
    end

    def _dedup_keys
      keys = custom_response_result.dig("dedup_keys")
      Array(keys).compact_blank.map(&:to_s).uniq
    end

    def _incident
      ActiveModel::Type::Boolean.new.cast(custom_response_result.dig("incident"))
    end

    def _incident_severity
      custom_response_result.dig("incident_severity")
    end

    def _incident_message
      custom_response_result.dig("incident_message")
    end

    def _tags
      tags = custom_response_result.dig("tags")
      Array(tags).compact_blank.map(&:to_s).uniq
    end

    def _meta
      custom_response_result.dig("meta") || {}
    end

    def _additional_datums
      custom_response_result.dig("additional_data") || []
    end
  end
end
