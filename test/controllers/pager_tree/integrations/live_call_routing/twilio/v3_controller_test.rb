require "test_helper"

module PagerTree::Integrations
  class LiveCallRouting::Twilio::V3ControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers
    include ActiveJob::TestHelper

    setup do
      @integration = pager_tree_integrations_integrations(:live_call_routing_twilio_v3)
    end

    test "responds_to_music_url" do
      get music_live_call_routing_twilio_v3_url(@integration)

      assert_response :success
      assert response.body.include?("http://com.twilio.sounds.music.s3.amazonaws.com/oldDog_-_endless_goodbye_%28instr.%29.mp3")
    end

    test "queues_a_deferred_request" do
      assert_no_performed_jobs
      assert_no_enqueued_jobs

      post queue_status_live_call_routing_twilio_v3_url(@integration)
      assert_response :success

      assert_enqueued_jobs 1
    end

    test "peforms_a_deferred_request" do
      assert_no_performed_jobs
      assert_no_enqueued_jobs

      post queue_status_live_call_routing_twilio_v3_url(@integration, format: :json, params: {
        CallSid: "CA1234567890123456789012345678901234567890",
        QueueResult: "in-progress"
      })
      assert_response :success

      assert_enqueued_jobs 1

      perform_enqueued_jobs

      assert_performed_jobs 1
      assert_enqueued_jobs 0
    end
  end
end
