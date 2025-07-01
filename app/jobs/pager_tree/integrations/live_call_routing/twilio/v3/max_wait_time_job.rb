class PagerTree::Integrations::LiveCallRouting::Twilio::V3::MaxWaitTimeJob < ApplicationJob
  queue_as :default

  def perform(*args)
    integration_id = args[0]
    alert_id = args[1]

    integration = Integration.find(integration_id)
    integration.max_wait_time_reached!(alert_id)
  rescue => e
    Rails.logger.error("MaxWaitTimeJob failed: #{e.message}")
  end
end
