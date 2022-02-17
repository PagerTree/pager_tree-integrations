require "pager_tree/integrations/version"
require "pager_tree/integrations/engine"

module PagerTree
  module Integrations
    mattr_accessor :integration_parent_class
    @@integration_parent_class = "ApplicationRecord"

    mattr_accessor :outgoing_webhook_delivery_parent_class
    @@outgoing_webhook_delivery_parent_class = "ApplicationRecord"

    mattr_accessor :outgoing_webhook_delivery_factory_class
    @@outgoing_webhook_delivery_factory_class = "PagerTree::Integrations::OutgoingWebhookDelivery::HookRelay"

    mattr_accessor :outgoing_webhook_delivery_table_name
    @@outgoing_webhook_delivery_table_name = "pager_tree_integrations_outgoing_webhook_deliveries"
  end
end
