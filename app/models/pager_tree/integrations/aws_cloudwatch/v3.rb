module PagerTree::Integrations
  class AwsCloudwatch::V3 < Integration
    OPTIONS = []
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    def adapter_supports_incoming?
      true
    end

    def adapter_incoming_can_defer?
      true
    end

    def adapter_should_block_incoming?(request)
      false
    end

    def adapter_thirdparty_id
      _thirdparty_id
    end

    def adapter_action
      if _is_create?
        :create
      elsif _is_resolve?
        :resolve
      else
        :other
      end
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        description: _description,
        thirdparty_id: _thirdparty_id,
        dedup_keys: [],
        additional_data: _additional_datums
      )
    end

    def adapter_process_other
      if _type == "SubscriptionConfirmation" || _type == "UnsubscribeConfirmation"
        url = _sns_notification.dig("SubscribeURL")
        HTTParty.get(url) if url
      end
    end

    private

    # the sns notification is sent with a text/plain but the text is formatted as json
    # need parse the text into json
    def _sns_notification
      @_sns_notification ||= begin
        JSON.parse(adapter_incoming_deferred_request.body).with_indifferent_access
      rescue
        {}
      end
    end

    def _type
      @_type ||= _sns_notification.dig("Type")
    end

    def _message
      @_message ||= _sns_notification.dig("Message")
    end

    def _json
      @_json ||= {} if _type != "Notification" || _message.blank?
      @_json ||= begin
        JSON.parse(_message).with_indifferent_access
      rescue
        {}
      end
    end

    def _thirdparty_id
      [
        _sns_notification.dig("TopicArn"),
        _json.dig("AlarmName")
      ].join(":")
    end

    def _is_create?
      _new_state == "ALARM" && (_old_state == "INSUFFICIENT_DATA" || _old_state == "OK")
    end

    def _is_resolve?
      _new_state == "OK" && (_old_state == "INSUFFICIENT_DATA" || _old_state == "ALARM")
    end

    def _new_state
      _json.dig("NewStateValue")
    end

    def _old_state
      _json.dig("OldStateValue")
    end

    def _title
      _json.dig("AlarmName")
    end

    def _description
      _json.dig("NewStateReason")
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "text", label: "AWS Account ID", value: _json.dig("AWSAccountId")),
        AdditionalDatum.new(format: "text", label: "Region", value: _json.dig("Region")),
        AdditionalDatum.new(format: "text", label: "Alarm ARN", value: _json.dig("AlarmArn")),
        AdditionalDatum.new(format: "datetime", label: "State Change Time", value: _json.dig("StateChangeTime"))
      ]
    end
  end
end
