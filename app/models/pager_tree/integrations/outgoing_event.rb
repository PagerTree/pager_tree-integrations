module PagerTree::Integrations
  class OutgoingEvent
    include ActiveModel::Model
    include ActiveModel::API
    extend ActiveModel::Callbacks

    attr_accessor :event_name
    attr_accessor :item
    attr_accessor :changes
    attr_accessor :outgoing_rules_data
    attr_accessor :alert
    attr_accessor :handoff
    attr_accessor :team
    attr_accessor :account_user
    attr_accessor :comment
    attr_accessor :event_reminder

    define_model_callbacks :initialize

    def initialize(params = {})
      run_callbacks :initialize do
        super(params)
      end
    end

    after_initialize do
      self.event_name ||= nil
      self.item ||= nil
      self.changes ||= nil
      self.outgoing_rules_data ||= {}

      self.alert ||= nil
      self.handoff ||= nil
      self.team ||= nil
      self.account_user ||= nil
      self.comment ||= nil
      self.event_reminder ||= nil
    end
  end
end
