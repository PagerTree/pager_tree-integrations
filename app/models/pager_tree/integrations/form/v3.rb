module PagerTree::Integrations
  class Form::V3 < Integration
    OPTIONS = [
      {key: :form_title, type: :string, default: ""},
      {key: :form_header, type: :string, default: ""},
      {key: :form_instructions, type: :string, default: ""},
      {key: :form_footer_text, type: :string, default: ""},
      {key: :form_footer_link, type: :string, default: ""},
      {key: :form_email_required, type: :boolean, default: false},
      {key: :form_phone_required, type: :boolean, default: false},
      {key: :form_description_required, type: :boolean, default: false},
      {key: :form_urgency_required, type: :boolean, default: false}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    has_one_attached :option_form_logo

    validates :option_form_footer_link, url: {no_local: true, allow_blank: true, allow_nil: true}
    validates :option_form_email_required, inclusion: {in: [true, false]}
    validates :option_form_phone_required, inclusion: {in: [true, false]}
    validates :option_form_description_required, inclusion: {in: [true, false]}
    validates :option_form_urgency_required, inclusion: {in: [true, false]}

    after_initialize do
      self.option_form_title ||= ""
      self.option_form_header ||= ""
      self.option_form_instructions ||= ""
      self.option_form_footer_text ||= ""
      self.option_form_footer_link ||= ""
      self.option_form_email_required ||= false
      self.option_form_phone_required ||= false
      self.option_form_description_required ||= false
      self.option_form_urgency_required ||= false
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

    def adapter_supports_cnames?
      true
    end

    def adapter_response_inactive_subscription
      adapter_controller&.render(status: :payment_required, json: {code: Rack::Utils.status_code(:payment_required), errors: ["Customer must subscribe service plan to use this integration"]})
    end

    def adapter_response_upgrade
      adapter_controller&.render(status: :payment_required, json: {code: Rack::Utils.status_code(:payment_required), errors: ["Customer must upgrade service plan to use this integration"]})
    end

    def adapter_response_maintenance_mode
      adapter_controller&.render(status: :service_unavailable, json: {code: Rack::Utils.status_code(:service_unavailable), errors: ["Integration currently in maintenance mode"]})
    end

    def adapter_thirdparty_id
      SecureRandom.uuid
    end

    def adapter_action
      :create
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        description: _description,
        urgency: _urgency,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [adapter_thirdparty_id],
        additional_data: _additional_datums
      )
    end

    private

    def _title
      adapter_incoming_request_params.dig("title")
    end

    def _description
      adapter_incoming_request_params.dig("description")
    end

    def _urgency
      case adapter_incoming_request_params.dig("urgency")
      when "low"
        "low"
      when "medium"
        "medium"
      when "high"
        "high"
      when "critical"
        "critical"
      end
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "text", label: "Name", value: adapter_incoming_request_params.dig("name")),
        AdditionalDatum.new(format: "email", label: "Email", value: adapter_incoming_request_params.dig("email")),
        AdditionalDatum.new(format: "phone", label: "Phone", value: adapter_incoming_request_params.dig("phone"))
      ]
    end
  end
end
