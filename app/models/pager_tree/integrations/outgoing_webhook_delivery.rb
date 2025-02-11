module PagerTree::Integrations
  class OutgoingWebhookDelivery
    def self.factory(**params)
      PagerTree::Integrations.outgoing_webhook_delivery_factory_class.constantize.factory(**params)
    end
  end
end
