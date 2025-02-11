module PagerTree::Integrations
  class EchoesHq::V3 < Integration
    OPTIONS = [
      {key: :api_key, type: :string, default: nil}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    validates :option_api_key, presence: true

    after_initialize do
      self.option_api_key ||= nil
    end

    def adapter_supports_incoming?
      false
    end

    def adapter_supports_outgoing?
      true
    end

    def adapter_show_outgoing_webhook_delivery?
      false
    end

    def adapter_supports_title_template?
      false
    end

    def adapter_supports_description_template?
      false
    end

    def adapter_supports_auto_aggregate?
      false
    end

    def adapter_supports_auto_resolve?
      false
    end

    def adapter_outgoing_interest?(event_name)
      ["alert_open", "alert_acknowledged", "alert_resolved"].include?(event_name.to_s)
    end

    def adapter_process_outgoing
      @pager_tree_alert = adapter_outgoing_event.alert

      create_or_update_echoes_hq_incident
    end

    private

    def echoes_hq_incident_id
      "PAGERTREE_#{@pager_tree_alert.tiny_id}"
    end

    def echoes_hq_status
      case @pager_tree_alert.status.to_s
      when "acknowledged" then "acknowledged"
      when "resolved" then "resolved"
      else
        "triggered"
      end
    end

    def echoes_hq_headers
      {
        Accept: "application/json",
        "Content-Type": "application/json",
        Authorization: "Bearer #{option_api_key}"
      }
    end

    def get_echoes_hq_incident
      result = nil
      response = nil
      url = "https://api.echoeshq.com/v1/signals/incidents/#{echoes_hq_incident_id}"
      response = HTTParty.get(url, headers: echoes_hq_headers, timeout: 3)
      result = response.code == 200 ? response.parsed_response : nil
    rescue
      result = nil
    ensure
      logs.create(level: :info, format: :json, message: {
        message: "GET EchoesHQ Incident for PagerTree alert ##{@pager_tree_alert.tiny_id}",
        url: url,
        response: response
      })

      result
    end

    def create_echoes_hq_incident
      result = nil
      response = nil
      url = "https://api.echoeshq.com/v1/signals/incidents"
      body = {
        id: echoes_hq_incident_id,
        title: @pager_tree_alert.title,
        service: {
          name: @pager_tree_alert.source&.name || name
        },
        started_at: @pager_tree_alert.created_at.iso8601
      }

      response = HTTParty.post(url, body: body.to_json, headers: echoes_hq_headers, timeout: 3)
      result = response.code == 200 ? response.parsed_response : nil
    rescue
      result = nil
    ensure
      logs.create(level: :info, format: :json, message: {
        message: "CREATE EchoesHQ Incident for PagerTree alert ##{@pager_tree_alert.tiny_id}",
        url: url,
        body: body,
        reponse: response
      })

      result
    end

    def update_echoes_hq_incident
      result = nil
      response = nil
      url = "https://api.echoeshq.com/v1/signals/incidents/#{echoes_hq_incident_id}"
      body = {
        title: @pager_tree_alert.title,
        status: echoes_hq_status,
        resolved_at: @pager_tree_alert.resolved_at&.iso8601
      }
      response = HTTParty.put(url, body: body.to_json, headers: echoes_hq_headers, timeout: 3)
      result = response.code == 200 ? response.parsed_response : nil
    rescue
      result = nil
    ensure
      logs.create(level: :info, format: :json, message: {
        message: "UPDATE EchoesHQ Incident for PagerTree alert ##{@pager_tree_alert.tiny_id}",
        url: url,
        body: body,
        response: response
      })

      result
    end

    def create_or_update_echoes_hq_incident
      create_echoes_hq_incident unless get_echoes_hq_incident.present?
      update_echoes_hq_incident
    end
  end
end
