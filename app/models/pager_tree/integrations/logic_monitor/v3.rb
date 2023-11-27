module PagerTree::Integrations
  class LogicMonitor::V3 < Integration
    OPTIONS = [
      {key: :alert_acknowledged, type: :boolean, default: false},
      {key: :logic_monitor_account_name, type: :string, default: nil},
      {key: :access_id, type: :string, default: nil},
      {key: :access_key, type: :string, default: nil},
      {key: :bearer_token, type: :string, default: nil}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    validates :option_alert_acknowledged, inclusion: {in: [true, false]}
    validates :option_logic_monitor_account_name, presence: true, if: -> { option_alert_acknowledged == true }
    validates :option_access_key, presence: true, if: -> { option_alert_acknowledged == true }
    validates :option_access_id, presence: true, if: -> { option_alert_acknowledged == true }
    validates :option_bearer_token, presence: true, if: -> { option_alert_acknowledged == true }

    after_initialize do
      self.option_alert_acknowledged = false if option_alert_acknowledged.nil?
    end

    def adapter_supports_incoming?
      true
    end

    def adapter_supports_outgoing?
      true
    end

    def adapter_outgoing_interest?(event_name)
      try("option_#{event_name}") || false
    end

    def adapter_show_outgoing_webhook_delivery?
      true
    end

    def adapter_incoming_can_defer?
      true
    end

    def adapter_thirdparty_id
      adapter_incoming_request_params.dig("internalid")
    end

    def adapter_action
      alert_status = adapter_incoming_request_params.dig("alertstatus")
      case alert_status
      when "active", "test"
        :create
      when "ack"
        :acknowledge
      when "clear"
        :resolve
      else
        :other
      end
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        description: _description,
        urgency: _urgency,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [],
        additional_data: _additional_datums
      )
    end

    def adapter_process_outgoing
      event = adapter_outgoing_event.event_name.to_s

      # only send sync to logic monitor if logic monitor is the source
      if event == "alert_acknowledged" && option_alert_acknowledged == true && adapter_outgoing_event.alert.source == self
        _on_acknowledge
      end
    end

    private

    def _title
      adapter_incoming_request_params.dig("eventmsg")
    end

    def _description
      adapter_incoming_request_params.dig("eventlogmsg")
    end

    def _urgency
      level = adapter_incoming_request_params.dig("level").to_s.downcase
      case level
      when "warn", "warning"
        "medium"
      when "error"
        "high"
      when "critical"
        "critical"
      end
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "text", label: "Host", value: adapter_incoming_request_params.dig("host")),
        AdditionalDatum.new(format: "text", label: "Service", value: adapter_incoming_request_params.dig("service"))
      ]
    end

    def _on_acknowledge
      lm_alert_id = adapter_outgoing_event.alert.thirdparty_id
      acknowledger = adapter_outgoing_event.account_user&.name || name || "someone"
      http_verb = "POST"

      if adapter_outgoing_event.alert.source_log&.message&.dig("params", "alerttype") == "agentDownAlert"
        # try to get the collector id
        collector_id = lm_alert_id.gsub(/[^0-9]/, "")
        resource_path = "/setting/collector/collectors/#{collector_id}/ackdown?v=2"
        data = {comment: "Acknowledged by #{acknowledger}"}
        send_request_with_bearer_token(resource_path, http_verb, data)
      else
        resource_path = "/alert/alerts/#{lm_alert_id}/ack"
        data = {ackComment: "Acknowledged by #{acknowledger}"}
        send_request_with_hmac(resource_path, http_verb, data)
      end
    end

    # https://www.logicmonitor.com/support/rest-api-authentication
    def send_request_with_hmac(resource_path, http_verb, data)
      base_url = "https://#{option_logic_monitor_account_name}.logicmonitor.com/santaba/rest"
      url = base_url + resource_path
      timestamp_ms = Time.current.to_i * 1000
      data_string = data.to_json
      # https://gist.github.com/abeland/e09a559e243f70670f2f4da3fd0fdabd
      signature = Base64.urlsafe_encode64(
        OpenSSL::HMAC.hexdigest(
          "SHA256",
          option_access_key,
          (http_verb.upcase + timestamp_ms.to_s + data_string + resource_path)
        )
      )
      headers = {
        "Content-Type" => "application/json",
        "Authorization" => "LMv1 #{option_access_id}:#{signature}:#{timestamp_ms}"
      }

      # note outgoing webhook delivery only supports the post method
      outgoing_webhook_delivery = OutgoingWebhookDelivery.factory(
        resource: self,
        url: url,
        body: data,
        options: {headers: headers}
      )
      outgoing_webhook_delivery.save!
      outgoing_webhook_delivery.deliver_later

      outgoing_webhook_delivery
    end

    def send_request_with_bearer_token(resource_path, http_verb, data)
      base_url = "https://#{option_logic_monitor_account_name}.logicmonitor.com/santaba/rest"
      url = base_url + resource_path
      headers = {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{option_bearer_token}"
      }

      # note outgoing webhook delivery only supports the post method
      outgoing_webhook_delivery = OutgoingWebhookDelivery.factory(
        resource: self,
        url: url,
        body: data,
        options: {headers: headers}
      )
      outgoing_webhook_delivery.save!
      outgoing_webhook_delivery.deliver_later

      outgoing_webhook_delivery
    end
  end
end

#  https://www.logicmonitor.com/support/alerts/integrations/custom-http-delivery
#  {
#   "alertid": "LMS22",
#   "alertstatus": "active",
#   "datasource": "WinVolumeUsage-C:\",
#   "datapoint": "PercentUsed",
#   "date": "2014-05-02 14:21:40 PDT",
#   "dsdesc": "Monitors space usage on logical volumes.",
#   "dsidesc": null,
#   "datapointdesc": "Percentage Used on the volume",
#   "group": "group1,group2",
#   "host": "opsgenie-test-server",
#   "hostdesc": "Server used for testing OpsGenie integrations",
#   "instance": "C:\",
#   "level": "warning",
#   "duration": "1465",
#   "threshold": "10",
#   "eventsource": "WinVolumeUsage-C:\",
#   "eventlogfile": "Application",
#   "eventtype": "information",
#   "eventmsg": "Percentage used on the volume exceeded 80%",
#   "eventlogmsg": "Remaining capacity(1456750MB) of volume C:\ is lower than 25%",
#   "eventcode": "1847502394",
#   "eventuser": "test-user",
#   "value": "83",
#   "batchdesc": "Monitors space usage on logical volumes everyday.",
#   "hostips": "123.456.789.012",
#   "hosturl": "https://opsgenie-test-server.net/",
#   "service": "webservice",
#   "alerttype": "error",
#   "agent": "opsgenie-test-server",
#   "checkpoint": "1879234",
#   "hostinfo": null,
#   "servicedetail": null,
#   "serviceurl": "https://opsgenie-test-server.net/",
#   "servicegroup": "Functional Testing",
#   "clearvalue": "1"
# }

# {
#   "service": "##SERVICE##",
#   "alertid": "##ALERTID##",
#   "alerttype": "##ALERTTYPE##",
#   "alertstatus": "##ALERTSTATUS##",
#   "level": "##LEVEL##",
#   "host": "##HOST##",
#   "datasource": "##DATASOURCE##",
#   "eventsource": "##EVENTSOURCE##",
#   "batchjob": "##BATCHJOB##",
#   "group": "##GROUP##",
#   "datapoint": "##DATAPOINT##",
#   "start": "##START##",
#   "finish": "##FINISH##",
#   "duration": "##DURATION##",
#   "value": "##VALUE##",
#   "threshold": "##THRESHOLD##",
#   "userdata": "##USERDATA##",
#   "cmdline": "##CMDLINE##",
#   "exitCode": "##EXITCODE##",
#   "stdout": "##STDOUT##",
#   "stderr": "##STDERR##",
#   "agent": "##AGENT_DESCRIPTION##",
#   "checkpoint": "##CHECKPOINT##",
#   "datapointdesc": "##DPDESCRIPTION##",
#   "hostdesc": "##HOSTDESCRIPTION##",
#   "hostinfo": "##system.sysinfo##",
#   "hostips": "##system.ips##",
#   "hosturl": "##DEVICEURL##",
#   "instance": "##INSTANCE##",
#   "dsidesc": "##DSIDESCRIPTION##",
#   "batchdesc": "##BJDESCRIPTION##",
#   "dsdesc": "##DSDESCRIPTION##",
#   "eventmsg": "##LIMITEDMESSAGE##",
#   "eventlogmsg": "##MESSAGE##",
#   "eventcode": "##EVENTCODE##",
#   "eventtype": "##TYPE##",
#   "eventuser": "##USER##",
#   "eventlogfile": "##LOGFILE##",
#   "eventsource": "##SOURCENAME##",
#   "servicedetail": "##DETAIL##",
#   "serviceurl": "##URL##",
#   "servicegroup": "##SERVICEGROUP##",
#   "date": "##DATE##",
#   "clearvalue": "##CLEARVALUE##",
#   "hostname": "##system.hostname##"
# }
