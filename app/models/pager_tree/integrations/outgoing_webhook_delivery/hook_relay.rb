module PagerTree::Integrations
  class OutgoingWebhookDelivery::HookRelay < OutgoingWebhookDelivery
    extend ::PagerTree::Integrations::Env

    define_model_callbacks :deliver

    def self.factory(**params)
      new(**params)
    end

    def self.hook_relay_account_id
      find_value_by_name(:hook_relay, :account_id)
    end

    def self.hook_relay_hook_id
      find_value_by_name(:hook_relay, :hook_id)
    end

    def self.hook_relay_api_key
      find_value_by_name(:hook_relay, :api_key)
    end

    def hook_relay_hook_url
      "https://api.hookrelay.dev/hooks/#{OutgoingWebhookDelivery::HookRelay.hook_relay_account_id}/#{OutgoingWebhookDelivery::HookRelay.hook_relay_hook_id}"
    end

    def hook_relay_delivery_url
      "https://app.hookrelay.dev/api/v1/accounts/#{OutgoingWebhookDelivery::HookRelay.hook_relay_account_id}/hooks/#{OutgoingWebhookDelivery::HookRelay.hook_relay_hook_id}/deliveries/#{thirdparty_id}"
    end

    def deliver_later
      OutgoingWebhookJob.perform_later(id, :deliver)
    end

    def deliver
      run_callbacks :deliver do
        begin
          response = HTTParty.post(hook_relay_hook_url, body: body.to_json, **httparty_opts)

          self.thirdparty_id = response["id"]
          self.status = :sent
        rescue => exception
          Rails.logger.error(exception)
          self.status = :failure
        end
        save!
      end # run_callbacks
    end

    def httparty_opts
      hook_relay_options = {
        headers: {
          "HR_TARGET_URL" => url
        }
      }

      pagertree_options = {
        headers: {
          "Accept" => "*/*",
          "User-Agent" => "pagertree outgoing webhook service; ref: #{resource&.id}; report: support@pagertree.com",
          "Content-Type" => "application/json"
        }
      }

      auth_options = {}
      if auth.is_a?(Hash)
        auth_indifferent = auth.with_indifferent_access
        if (username = auth_indifferent.dig(:username)).present? && (password = auth_indifferent.dig(:password)).present?
          auth_options = {
            headers: {
              "Authorization" => Base64.strict_encode64("#{username}:#{password}")
            }
          }
        end
      end

      OutgoingWebhookDelivery::HTTP_OPTIONS
        .deep_merge(hook_relay_options)
        .deep_merge(pagertree_options)
        .deep_merge(auth_options)
        .deep_merge((options&.symbolize_keys || {}))
    end

    def delivery
      return @delivery if @delivery
      return {} unless thirdparty_id

      opts = {
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{OutgoingWebhookDelivery::HookRelay.hook_relay_api_key}"
        },
        timeout: 15
      }

      response = ::HTTParty.get(hook_relay_delivery_url, **opts)
      @delivery = response.parsed_response if response.success?

      @delivery || {}
    end

    def request
      delivery&.dig("request") || {}
    end

    def responses
      delivery&.dig("responses") || []
    end
  end
end
