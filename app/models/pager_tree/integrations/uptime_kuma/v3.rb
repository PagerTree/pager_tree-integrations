module PagerTree::Integrations
  class UptimeKuma::V3 < Integration
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
      adapter_incoming_request_params.dig("id")
    end

    def adapter_action
      case adapter_incoming_request_params.dig("event_type")
      when "create"
        :create
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
        tags: _tags,
        additional_data: _additional_datums
      )
    end

    private

    def _title
      adapter_incoming_request_params.dig("title")
    end

    def _description
      adapter_incoming_request_params.dig("heartbeat", "msg")
    end

    def _tags
      tags = adapter_incoming_request_params.dig("monitor", "tags")
      Array(tags).map { |x| x["name"] }.compact_blank.map(&:to_s).uniq
    end

    def _urgency
      text = adapter_incoming_request_params.dig("urgency")
      matches = /(?<urgency>silent|low|medium|high|critical)/.match(text&.to_s&.downcase&.strip)
      matches ? matches[:urgency].to_s : nil
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "URL", value: adapter_incoming_request_params.dig("monitor", "url")),
        AdditionalDatum.new(format: "text", label: "Method", value: adapter_incoming_request_params.dig("monitor", "method")),
        AdditionalDatum.new(format: "datetime", label: "Time", value: adapter_incoming_request_params.dig("heartbeat", "time"))
      ]
    end
  end
end
