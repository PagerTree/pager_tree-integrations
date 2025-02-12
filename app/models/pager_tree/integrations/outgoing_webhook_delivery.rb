module PagerTree::Integrations
  class OutgoingWebhookDelivery < ApplicationRecord
    self.table_name = PagerTree::Integrations.outgoing_webhook_delivery_table_name

    serialize :data, JSON
    encrypts :data

    store_accessor :data, *[:url, :body, :auth, :options].map(&:to_s)

    HTTP_OPTIONS = {
      headers: {"Content-Type" => "application/json"},
      timeout: 15
    }

    belongs_to :resource, polymorphic: true
    enum status: {queued: 0, sent: 1, success: 2, failure: 3, retrying: 4, cancelled: 5, stored: 6, insufficent_funds: 7}

    def self.factory(**params)
      klass = PagerTree::Integrations.outgoing_webhook_delivery_factory_class
      (klass.is_a?(Proc) ? klass.call : klass.to_s).constantize.new(**params)
    end
  end
end
