module PagerTree::Integrations
  class OutgoingWebhookDelivery < PagerTree::Integrations.outgoing_webhook_delivery_parent_class.constantize
    self.table_name = PagerTree::Integrations.outgoing_webhook_delivery_table_name

    serialize :data, JSON
    encrypts :data

    store_accessor :data, *[:url, :body, :auth].map(&:to_s)

    HTTP_OPTIONS = {
      headers: {'Content-Type': "application/json"},
      timeout: 15
    }

    belongs_to :resource, polymorphic: true
    enum status: {queued: 0, sent: 1, success: 2, failure: 3, retrying: 4, cancelled: 5, stored: 6, insufficent_funds: 7}

    def self.factory(**params)
      PagerTree::Integrations.outgoing_webhook_delivery_factory_class.constantize.new(**params)
    end
  end
end
