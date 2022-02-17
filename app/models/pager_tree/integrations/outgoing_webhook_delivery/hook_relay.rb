module PagerTree::Integrations
  class OutgoingWebhookDelivery::HookRelay < OutgoingWebhookDelivery
    define_model_callbacks :deliver

    def hookrelay_account_id
      Rails.application.credentials.dig(:app, :hook_relay, :account_id)
    end

    def hookrelay_hook_id
      Rails.application.credentials.dig(:app, :hook_relay, :hook_id)
    end

    def hookrelay_api_key
      Rails.application.credentials.dig(:app, :hook_relay, :api_key)
    end

    def hookrelay_hook_url
      "https://api.hookrelay.dev/hooks/#{hookrelay_account_id}/#{hookrelay_hook_id}"
    end

    def hookrelay_delivery_url
      "https://app.hookrelay.dev/api/v1/accounts/#{hookrelay_account_id}/hooks/#{hookrelay_hook_id}/deliveries/#{thirdparty_id}"
    end

    def deliver_later
      OutgoingWebhookJob.perform_later(id, :deliver)
    end

    def deliver
      run_callbacks :deliver do
        begin
          hookrelay_options = {
            headers: {
              HR_TARGET_URL: url
            }
          }

          pagertree_options = {
            headers: {
              Accept: "*/*",
              'User-Agent': "pagertree outgoing webhook service; ref: #{resource&.id}; report: support@pagertree.com",
              'Content-Type': "application/json"
            }
          }

          auth_options = {}
          if auth.is_a?(Hash) && (username = auth.dig(:username)).present? && (password = auth.dig(:password)).present?
            auth_options = {
              headers: {
                Authorization: Base64.strict_encode64("#{username}:#{password}")
              }
            }
          end

          options = OutgoingWebhookDelivery::HTTP_OPTIONS
            .deep_merge(hookrelay_options)
            .deep_merge(pagertree_options)
            .deep_merge(auth_options)

          response = HTTParty.post(hookrelay_hook_url, body: body.to_json, **options)

          self.thirdparty_id = response["id"]
          self.status = :sent
        rescue => exception
          Rails.logger.error(exception)
          self.status = :failure
        end
        save!
      end # run_callbacks
    end

    def delivery
      return @delivery if @delivery
      return {} unless thirdparty_id

      options = {
        headers: {
          'Content-Type': "application/json",
          Authorization: "Bearer #{hookrelay_api_key}"
        },
        timeout: 15
      }

      @delivery = ::HTTParty.get(hookrelay_delivery_url, **options)
      @delivery
    end

    def request
      delivery.dig("request")
    end

    def responses
      delivery.dig("responses") || []
    end
  end
end
