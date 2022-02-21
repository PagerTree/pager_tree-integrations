module PagerTree::Integrations
  class LiveCallRouting::Twilio::V3Controller < ApplicationController
    skip_before_action :verify_authenticity_token

    def music
      set_integration

      @integration.adapter_source_log = @integration.logs.create!(level: :info, format: :json, message: params.to_unsafe_h) if @integration.log_incoming_requests?
      @integration.adapter_controller = self
      @integration.adapter_response_music
    end

    def queue_status
      ::PagerTree::Integrations.deferred_request_class.constantize.perform_later_from_request!(request)

      head :ok
    end

    def queue_status_deferred(deferred_request)
      params = deferred_request.params

      id = params.dig("id")
      @integration = LiveCallRouting::Twilio::V3.find_by!("id = ? OR prefix_id = ?", id, id)

      deferred_request.account_id = @integration.account_id

      @integration.adapter_source_log = @integration.logs.create!(level: :info, format: :json, message: deferred_request.request) if @integration.log_incoming_requests?
      @integration.adapter_incoming_request_params = params
      @integration.adapter_incoming_deferred_request = deferred_request

      @integration.adapter_process_queue_status_deferred
    end

    private
    
    def set_integration
      id = params[:id]
      @integration = LiveCallRouting::Twilio::V3.find_by!('id = ? OR prefix_id = ?', id, id)
    end

  end
end
