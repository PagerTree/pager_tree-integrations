module PagerTree::Integrations
  class UptimeRobot::V3 < Integration
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
      monitor_id = adapter_incoming_request_params.dig("monitorID")

      # LEGACY: We offerred the ability to aggregate for one of our customers
      # we did this through a groupSeconds parameter. Technically, with our new aggregration
      # this shouldn't be here, but to support our legacy customers it is.
      group_seconds = adapter_incoming_request_params.dig("groupSeconds").to_i

      return monitor_id unless group_seconds > 0

      alert_datetime = Time.at(adapter_incoming_request_params.dig("alertDateTime").to_i)

      # return the rounded off time as the id (as so to group them together by id)
      _round_off(alert_datetime, group_seconds.seconds).to_i
    end

    def adapter_action
      case adapter_incoming_request_params.dig("alertTypeFriendlyName").to_s.downcase
      when "down"
        :create
      when "up"
        :resolve
      else
        :other
      end
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        description: _description,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [adapter_thirdparty_id],
        additional_data: _additional_datums
      )
    end

    private

    def _title
      "#{adapter_incoming_request_params.dig("monitorFriendlyName")} is DOWN"
    end

    def _description
      "#{adapter_incoming_request_params.dig("monitorFriendlyName")} is DOWN because #{adapter_incoming_request_params.dig("alertDetails")}"
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Monitor URL", value: adapter_incoming_request_params.dig("monitorURL")),
        AdditionalDatum.new(format: "datetime", label: "Triggered At", value: Time.at(adapter_incoming_request_params.dig("alertDateTime").to_i).utc.to_datetime)
      ]
    end

    def _round_off(time, seconds)
      Time.at((time.to_f / seconds).floor * seconds).utc
    end
  end
end
