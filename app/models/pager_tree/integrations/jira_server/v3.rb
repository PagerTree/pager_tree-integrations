module PagerTree::Integrations
  class JiraServer::V3 < Integration
    OPTIONS = [
      {key: :issue_updated, type: :boolean, default: false}
    ]
    store_accessor :options, *OPTIONS.map { |x| x[:key] }.map(&:to_s), prefix: "option"

    validates :option_issue_updated, inclusion: {in: [true, false]}

    after_initialize do
      self.option_issue_updated ||= false
    end

    def adapter_supports_incoming?
      true
    end

    def adapter_supports_outgoing?
      false
    end

    def adapter_incoming_can_defer?
      true
    end

    def adapter_thirdparty_id
      adapter_incoming_request_params.dig("issue", "id")
    end

    def adapter_action
      event = adapter_incoming_request_params.dig("webhookEvent")
      event == "jira:issue_created" || (self.option_issue_updated == true && event == "jira:issue_updated") ? :create : :other
    end

    def adapter_process_create
      Alert.new(
        title: _title,
        description: _description,
        thirdparty_id: adapter_thirdparty_id,
        dedup_keys: [adapter_thirdparty_id],
        additional_data: _additional_datums
      )
    end

    private

    def _title
      adapter_incoming_request_params.dig("issue", "fields", "summary") || adapter_incoming_request_params.dig("issue", "key")
    end

    def _description
      adapter_incoming_request_params.dig("issue", "fields", "description")
    end

    def _additional_datums
      [
        AdditionalDatum.new(format: "link", label: "Issue URL", value: adapter_incoming_request_params.dig("issue", "self"))
      ]
    end
  end
end
