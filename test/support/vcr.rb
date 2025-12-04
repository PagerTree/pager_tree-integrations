require "vcr"

unless ENV["SKIP_VCR"]
  require "webmock/minitest"

  VCR.configure do |c|
    c.cassette_library_dir = "test/vcr_cassettes"
    c.hook_into :webmock
    c.allow_http_connections_when_no_cassette = true
    c.filter_sensitive_data("<HOOK_RELAY_ACCOUNT_ID>") { PagerTree::Integrations::OutgoingWebhookDelivery::HookRelay.hook_relay_account_id }
    c.filter_sensitive_data("<HOOK_RELAY_HOOK_ID>") { PagerTree::Integrations::OutgoingWebhookDelivery::HookRelay.hook_relay_hook_id }
    c.filter_sensitive_data("<HOOK_RELAY_API_KEY>") { PagerTree::Integrations::OutgoingWebhookDelivery::HookRelay.hook_relay_api_key }
    c.filter_sensitive_data("<INTEGRATION_CUSTOM_WEBHOOK_V3_SERVICE_URL>"){ PagerTree::Integrations::CustomWebhook::V3.custom_webhook_v3_service_url }
  end

  class ActiveSupport::TestCase
    setup do
      VCR.insert_cassette name, allow_unused_http_interactions: false
    end

    teardown do
      cassette = VCR.current_cassette
      VCR.eject_cassette
    rescue VCR::Errors::UnusedHTTPInteractionError
      puts
      puts "Unused HTTP requests in cassette: #{cassette.file}"
      raise
    end
  end
end
