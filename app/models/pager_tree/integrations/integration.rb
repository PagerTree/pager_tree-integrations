module PagerTree::Integrations
  class Integration < PagerTree::Integrations.integration_parent_class.constantize
    serialize :options, JSON
    encrypts :options

    GENERIC_OPTIONS = [
      {key: :title_template, type: :string, default: nil},
      {key: :title_template_enabled, type: :boolean, default: false},
      {key: :description_template, type: :string, default: nil},
      {key: :description_template_enabled, type: :string, default: false}
    ]
    store_accessor :options, *GENERIC_OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    before_validation :cast_types

    attribute :option_title_template_enabled, :boolean, default: false
    attribute :option_description_template_enabled, :boolean, default: false
    attribute :option_title_template, :string, default: nil
    attribute :option_description_template, :string, default: nil

    # careful controller is not always guaranteed
    attribute :adapter_controller
    # for handling incoming requests
    attribute :adapter_incoming_request_params
    # for getting the most data, but not always guaranteed
    attribute :adapter_incoming_deferred_request
    # alert if found (by thirdparty id)
    attribute :adapter_alert
    # the outgoing event
    attribute :adapter_outgoing_event

    # START basic incoming functions
    def adapter_supports_incoming?
      false
    end

    # A unique identifier for this integration/alert
    def adapter_thirdparty_id
      ULID.generate
    end

    def adapter_incoming_can_defer?
      true
    end

    # Returns :create, :acknowledge, :resolve, or :other
    def adapter_action
      :other
    end

    def adapter_process_create
    end
    # END basic incoming functions

    # START basic outgoing functions
    def adapter_supports_outgoing?
      false
    end

    def adapter_outgoing_interest?(event_name)
      false
    end

    def adapter_process_outgoing
    end
    # END basic outgoing functions

    # START basic show functions
    def adapter_show_alerts?
      adapter_supports_incoming?
    end

    def adapter_show_logs?
      true
    end

    def adapter_show_outgoing_webhook_delivery?
      false
    end
    # END basic show functions

    def adapter_response_rate_limit
      adapter_controller&.head(:not_found)
    end

    def adapter_response_disabled
      adapter_controller&.head(:method_not_allowed)
    end

    def adapter_response_inactive_subscription
      adapter_controller&.head(:payment_required)
    end

    def adapter_response_upgrade
      adapter_controller&.head(:payment_required)
    end

    def adapter_response_maintenance_mode
      adapter_controller&.head(:ok)
    end

    def adapter_response_blocked
      adapter_controller&.head(:bad_request)
    end

    def adapter_response_deferred
      adapter_controller&.head(:ok)
    end

    def adapter_response_incoming
      adapter_controller&.head(:ok)
    end

    def cast_types
      (self.class.const_get(:GENERIC_OPTIONS) + self.class.const_get(:OPTIONS)).each do |option|
        key = option[:key]
        value = send("option_#{key}")
        type = option[:type]

        value = ActiveModel::Type::Boolean.new.cast(value) if type == :boolean
        value = ActiveModel::Type::String.new.cast(value) if type == :string
        value = ActiveModel::Type::Integer.new.cast(value) if type == :integer

        value = option[:default] if value.nil? && option.has_key?(:default)

        send("option_#{key}=", value)
      end
    end
  end
end
