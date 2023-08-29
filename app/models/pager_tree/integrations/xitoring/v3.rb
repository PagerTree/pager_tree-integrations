module PagerTree::Integrations
  class Xitoring::V3 < Integration
    # TODO: Add options that are relevant to your integration
    OPTIONS = [
      # {key: :api_key, type: :string, default: nil},
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"
    
    # TODO - add some validations for your options
    # validates :option_api_key, presence: true

    # TODO - add defaults for your options
    after_initialize do
      # self.option_api_key ||= nil
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

    # TODO: A unique identifier for this integration/alert
    def adapter_thirdparty_id
      adapter_incoming_request_params.dig("id")
    end

    # TODO: Returns :create, :resolve, or :other
    def adapter_action
      case adapter_incoming_request_params.dig("status")
      when 0 then :create
      when 1 then :resolve
      else :other
      end
    end

    def status_human
      case adapter_incoming_request_params.dig("status")
      when 0 then "Down"
      when 1 then "Up"
      else "Unknown"
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
      "[#{adapter_incoming_request_params.dig("tpye_human_readable")}] #{adapter_incoming_request_params.dig("label")} is #{status_human}"
    end

    def _description
      adapter_incoming_request_params.dig("message")
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "text", label: "Group", value: adapter_incoming_request_params.dig("group")),
        AdditionalDatum.new(format: "text", label: "Subgroup", value: adapter_incoming_request_params.dig("sub_group")),
        AdditionalDatum.new(format: "text", label: "Value", value: adapter_incoming_request_params.dig("value")),
        AdditionalDatum.new(format: "text", label: "Unit", value: adapter_incoming_request_params.dig("unit")),
        AdditionalDatum.new(format: "datetime", label: "Incident Time", value: adapter_incoming_request_params.dig("incident_time"))
      ]
    end
  end
end
