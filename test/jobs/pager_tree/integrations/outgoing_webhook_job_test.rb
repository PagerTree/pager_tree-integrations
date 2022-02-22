require "test_helper"

module PagerTree::Integrations
  class OutgoingWebhookJobTest < ActiveJob::TestCase
    test "job_can_be_performed_later" do
      assert_no_enqueued_jobs
      assert_no_performed_jobs

      @outgoing_webhook_delivery = pager_tree_integrations_outgoing_webhook_deliveries(:hook_relay_queued)
      assert_equal :queued.to_s, @outgoing_webhook_delivery.status

      @outgoing_webhook_delivery.deliver_later

      assert_enqueued_jobs 1

      VCR.use_cassette("outgoing_webhook_job_job_can_be_performed_later") do
        perform_enqueued_jobs
      end

      assert_no_enqueued_jobs
      assert_performed_jobs 1

      @outgoing_webhook_delivery.reload
      assert_equal :sent.to_s, @outgoing_webhook_delivery.status
      assert @outgoing_webhook_delivery.thirdparty_id.present?
    end
  end
end
