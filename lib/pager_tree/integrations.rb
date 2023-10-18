require "pager_tree/integrations/version"
require "pager_tree/integrations/engine"

module PagerTree
  module Integrations
    autoload :Env, "pager_tree/integrations/env"

    mattr_accessor :deferred_request_class
    @@deferred_request_class = "DeferredRequest::DeferredRequest"

    mattr_accessor :integration_parent_class
    @@integration_parent_class = "ApplicationRecord"

    mattr_accessor :outgoing_webhook_delivery_parent_class
    @@outgoing_webhook_delivery_parent_class = "ApplicationRecord"

    mattr_accessor :outgoing_webhook_delivery_factory_class
    @@outgoing_webhook_delivery_factory_class = "PagerTree::Integrations::OutgoingWebhookDelivery::HookRelay"

    mattr_accessor :outgoing_webhook_delivery_table_name
    @@outgoing_webhook_delivery_table_name = "pager_tree_integrations_outgoing_webhook_deliveries"

    mattr_accessor :integration_email_v3_domain
    @@integration_email_v3_domain = "alerts.pagertree.com"

    mattr_accessor :integration_email_v3_inbox
    @@integration_email_v3_inbox = "a"

    mattr_accessor :integration_sentry_v3_client_id
    @@integration_sentry_v3_client_id = ""

    mattr_accessor :integration_sentry_v3_client_secret
    @@integration_sentry_v3_client_secret = ""
  end
end
