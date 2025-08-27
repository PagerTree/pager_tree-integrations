module PagerTree::Integrations
  class Zabbix::V3 < Integration
    OPTIONS = [
      {key: :map_urgency, type: :boolean, default: false}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    validates :option_map_urgency, inclusion: {in: [true, false]}

    after_initialize do
      self.option_map_urgency ||= false
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
      adapter_incoming_request_params.dig("trigger_id").presence || adapter_incoming_request_params.dig("event_id").presence || ULID.generate
    end

    def adapter_action
      case adapter_incoming_request_params.dig("event_value")
      when "{EVENT.VALUE}" then :create # testing scenario
      when "1" then :create
      when "0" then :resolve
      else :other
      end
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        description: _description,
        urgency: _urgency,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [],
        tags: _tags,
        additional_data: _additional_datums
      )
    end

    private

    def _title
      adapter_incoming_request_params.dig("title")
    end

    def _description
      ["<pre>", adapter_incoming_request_params.dig("description"), "</pre>"].join
    end

    def _urgency
      if self.option_map_urgency == true
        case adapter_incoming_request_params.dig("event_nseverity")
        when "0" then "silent" # Not Classified
        when "1" then "low" # Information
        when "2" then "medium" # Warning
        when "3" then "medium" # Average
        when "4" then "high" # High
        when "5" then "critical" # Disaster
        end
      end
    end

    def _tags
      (adapter_incoming_request_params.dig("event_tags") || "").split(",").map(&:strip).uniq.compact
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Zabbix URL", value: _zabbix_url)
      ]
    end

    def _zabbix_url
      event_source = adapter_incoming_request_params.dig("event_source")
      url = adapter_incoming_request_params.dig("zabbix_url")

      if event_source == "0"
        url = "#{url}/tr_events.php?triggerid=#{adapter_incoming_request_params.dig("trigger_id")}&eventid=#{adapter_incoming_request_params.dig("event_id")}"
      end

      url
    end
  end
end
