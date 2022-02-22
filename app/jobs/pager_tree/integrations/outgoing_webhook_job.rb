module PagerTree::Integrations
  class OutgoingWebhookJob < ApplicationJob
    queue_as :default

    def perform(*args)
      id = args[0]
      method = args[1]
      outgoing_webhook_delivery = OutgoingWebhookDelivery.find(id)
      outgoing_webhook_delivery.send(method, *args[2..])
    end
  end
end
