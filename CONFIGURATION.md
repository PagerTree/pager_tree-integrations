You can configure this gem with an initializer file:
```ruby
# config/initializers/pagertree_integrations.rb
PagerTree::Integrations.deferred_request_class = "DeferredReq"
PagerTree::Integrations.integration_parent_class = "Integration"
PagerTree::Integrations.outgoing_webhook_delivery_factory_class = "OutgoingWebhookDeliv"
...
```

## Global Options
These options are for the core PagerTree integrations model

### Integration
`integration_parent_class` - The main app's integration class name

### Deferred Request
`deferred_request_class` - The main app's deferred request class name

### Outgoing Webhook
`outgoing_webhook_delivery_parent_class` - The main app's outgoing webhook class
`outgoing_webhook_delivery_factory_class` - The desired class to initialize outgoing webhooks as
`outgoing_webhook_delivery_table_name` - The mains app's database table name for outgoing webhook deliveries

## Integration Options
These options are specific to each integration.

### Email
`integration_email_v3_domain` - The incoming email domain
`integration_email_v3_inbox` - The incoming email inbox
