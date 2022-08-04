module PagerTree::Integrations
  class Prtg::V3 < Integration
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
      adapter_incoming_request_params.dig("sensorid")
    end

    def adapter_action
      status = adapter_incoming_request_params.dig("status").to_s.downcase

      if status == "down"
        :create
      elsif status.include?("now: up")
        :resolve
      else
        :other
      end
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [adapter_thirdparty_id],
        additional_data: _additional_datums
      )
    end

    private

    def _title
      "Sensor #{adapter_incoming_request_params.dig("sensorid")} #{adapter_incoming_request_params.dig("sensor")} is DOWN"
    end

    def _additional_datums
      adapter_incoming_request_params.map do |key, value|
        AdditionalDatum.new(format: "text", label: key, value: value.to_s)
      end
    end
  end
end
