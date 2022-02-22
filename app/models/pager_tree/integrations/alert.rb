module PagerTree::Integrations
  class Alert
    include ActiveModel::Model
    include ActiveModel::API
    extend ActiveModel::Callbacks

    attr_accessor :title
    attr_accessor :description
    attr_accessor :urgency
    attr_accessor :incident
    attr_accessor :incident_severity
    attr_accessor :incident_message
    attr_accessor :meta
    attr_accessor :thirdparty_id
    attr_accessor :dedup_keys
    attr_accessor :additional_data
    attr_accessor :attachments

    validates :title, presence: true
    validates :urgency, inclusion: {in: ["silent", "low", "medium", "high", "critical"]}, if: ->(x){x.urgency.present?}
    validates :incident, inclusion: {in: [true, false]}
    validates :incident_severity, presence: true, if: :incident?
    validates :thirdparty_id, presence: true

    define_model_callbacks :initialize

    def initialize(params = {})
      run_callbacks :initialize do
        super(params)
      end
    end

    after_initialize do
      self.title ||= nil
      self.description ||= nil
      self.urgency ||= nil
      self.meta ||= {}
      self.incident ||= false
      self.incident_severity ||= nil
      self.incident_message ||= nil
      self.thirdparty_id ||= nil
      self.dedup_keys ||= []
      self.additional_data ||= []
      self.attachments ||= []
    end

    def incident?
      ActiveModel::Type::Boolean.new.cast(self.incident)
    end

    def push_additional_data(additional_datum)
      if additional_datum.valid?
        self.additional_data.push(additional_data.to_json)
        true
      else
        false
      end
    end
  end
end
