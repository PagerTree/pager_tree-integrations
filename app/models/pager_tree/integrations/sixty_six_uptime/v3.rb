module PagerTree::Integrations
  class SixtySixUptime::V3 < Integration    
    OPTIONS = [
    ]
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
      id_part = case _webhoook_type
      when "website", "ping", "port" then adapter_incoming_request_params.dig("monitor_id")
      when "heartbeat" then adapter_incoming_request_params.dig("heartbeat_id")
      when "domain-expiry", "ssl-expiry" then adapter_incoming_request_params.dig("domain_name_id")
      else
        SecureRandom.uuid
      end
      "#{_webhoook_type}-#{id_part}"
    end

    def adapter_action
      case _webhoook_type
      when "website", "ping", "port", "heartbeat"
        adapter_incoming_request_params.dig("is_ok") == 1 ? :resolve : :create
      when "domain-expiry", "ssl-expiry"
        :create
      else 
        :other
      end
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
      case _webhoook_type
      when "website", "ping", "port" then "#{_webhoook_type.capitalize} monitor #{adapter_incoming_request_params.dig("name")} is DOWN"
      when "heartbeat" then "Heartbeat monitor #{adapter_incoming_request_params.dig("name")} has not checked in"
      when "domain-expiry" then "Domain monitor #{adapter_incoming_request_params.dig("name")} is expiring soon"
      when "ssl-expiry" then "SSL Certificate monitor #{adapter_incoming_request_params.dig("name")} is expiring soon"
      else 
        "Unknown Webhook Type"
      end
    end

    def _description
      case _webhoook_type
      when "website", "ping", "port" then "#{_webhoook_type.capitalize} monitor #{adapter_incoming_request_params.dig("name")} (#{adapter_incoming_request_params.dig("target")}) is DOWN"
      when "heartbeat" then "Heartbeat monitor #{adapter_incoming_request_params.dig("name")} has not checked in"
      when "domain-expiry" then "Domain monitor #{adapter_incoming_request_params.dig("name")} (#{adapter_incoming_request_params.dig("target")}) is expiring soon (#{adapter_incoming_request_params.dig("whois_end_datetime")} #{adapter_incoming_request_params.dig("timezone")})"
      when "ssl-expiry" then "SSL Certificate monitor #{adapter_incoming_request_params.dig("name")} (#{adapter_incoming_request_params.dig("target")}) is expiring soon (#{adapter_incoming_request_params.dig("ssl_end_datetime")} #{adapter_incoming_request_params.dig("timezone")})"
      else 
        "Unknown Webhook Type"
      end
    end

    def _additional_datums
      case _webhoook_type
      when "website", "ping", "port"
        [
          AdditionalDatum.new(format: "link", label: "URL", value: adapter_incoming_request_params.dig("url")),
          AdditionalDatum.new(format: "text", label: "Name", value: adapter_incoming_request_params.dig("name")),
          AdditionalDatum.new(format: "text", label: "Type", value: adapter_incoming_request_params.dig("type")),
          AdditionalDatum.new(format: "link", label: "Target", value: adapter_incoming_request_params.dig("target")),
          AdditionalDatum.new(format: "text", label: "port", value: adapter_incoming_request_params.dig("port"))
        ]
      when "heartbeat"
        [
          AdditionalDatum.new(format: "link", label: "URL", value: adapter_incoming_request_params.dig("url")),
          AdditionalDatum.new(format: "text", label: "Name", value: adapter_incoming_request_params.dig("name")),
          AdditionalDatum.new(format: "text", label: "Type", value: adapter_incoming_request_params.dig("type")),
        ]
      when "domain-expiry"
        [
          AdditionalDatum.new(format: "link", label: "URL", value: adapter_incoming_request_params.dig("url")),
          AdditionalDatum.new(format: "text", label: "Name", value: adapter_incoming_request_params.dig("name")),
          AdditionalDatum.new(format: "text", label: "Type", value: adapter_incoming_request_params.dig("type")),
          AdditionalDatum.new(format: "link", label: "Target", value: adapter_incoming_request_params.dig("target")),
          AdditionalDatum.new(format: "text", label: "WHOIS End DateTime", value: "#{adapter_incoming_request_params.dig("whois_end_datetime")} #{adapter_incoming_request_params.dig("timezone")}"),
        ]
      when "ssl-expiry"
        [
          AdditionalDatum.new(format: "link", label: "URL", value: adapter_incoming_request_params.dig("url")),
          AdditionalDatum.new(format: "text", label: "Name", value: adapter_incoming_request_params.dig("name")),
          AdditionalDatum.new(format: "text", label: "Type", value: adapter_incoming_request_params.dig("type")),
          AdditionalDatum.new(format: "link", label: "Target", value: adapter_incoming_request_params.dig("target")),
          AdditionalDatum.new(format: "text", label: "SSL End DateTime", value: "#{adapter_incoming_request_params.dig("ssl_end_datetime")} #{adapter_incoming_request_params.dig("timezone")}"),
        ]
      else
        []
      end
    end

    def _webhoook_type
      adapter_incoming_request_params.dig("type")
    end
  end
end
