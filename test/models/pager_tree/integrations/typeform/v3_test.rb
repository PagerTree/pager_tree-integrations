require "test_helper"

module PagerTree::Integrations
  class Typeform::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:typeform_v3)

      # https://developer.typeform.com/webhooks/example-payload/
      @create_request = {
        event_id: "LtWXD3crgy",
        event_type: "form_response",
        form_response: {
          form_id: "lT4Z3j",
          token: "a3a12ec67a1365927098a606107fac15",
          submitted_at: "2018-01-18T18:17:02Z",
          landed_at: "2018-01-18T18:07:02Z",
          calculated: {
            score: 9
          },
          variables: [
            {
              key: "score",
              type: "number",
              number: 4
            },
            {
              key: "name",
              type: "text",
              text: "typeform"
            }
          ],
          hidden: {
            user_id: "abc123456"
          },
          definition: {
            id: "lT4Z3j",
            title: "Webhooks example",
            fields: [
              {
                id: "DlXFaesGBpoF",
                title: "Thanks, {{answer_60906475}}! What's it like where you live? Tell us in a few sentences.",
                type: "long_text",
                ref: "[readable_ref_long_text",
                allow_multiple_selections: false,
                allow_other_choice: false
              },
              {
                id: "SMEUb7VJz92Q",
                title: "If you're OK with our city management following up if they have further questions, please give us your email address.",
                type: "email",
                ref: "readable_ref_email",
                allow_multiple_selections: false,
                allow_other_choice: false
              },
              {
                id: "JwWggjAKtOkA",
                title: "What is your first name?",
                type: "short_text",
                ref: "readable_ref_short_text",
                allow_multiple_selections: false,
                allow_other_choice: false
              },
              {
                id: "KoJxDM3c6x8h",
                title: "When did you move to the place where you live?",
                type: "date",
                ref: "readable_ref_date",
                allow_multiple_selections: false,
                allow_other_choice: false
              },
              {
                id: "PNe8ZKBK8C2Q",
                title: "Which pictures do you like? You can choose as many as you like.",
                type: "picture_choice",
                ref: "readable_ref_picture_choice",
                allow_multiple_selections: true,
                allow_other_choice: false
              },
              {
                id: "Q7M2XAwY04dW",
                title: "On a scale of 1 to 5, what rating would you give the weather in Sydney? 1 is poor weather, 5 is excellent weather",
                type: "number",
                ref: "readable_ref_number1",
                allow_multiple_selections: false,
                allow_other_choice: false
              },
              {
                id: "gFFf3xAkJKsr",
                title: "By submitting this form, you understand and accept that we will share your answers with city management. Your answers will be anonymous will not be shared.",
                type: "legal",
                ref: "readable_ref_legal",
                allow_multiple_selections: false,
                allow_other_choice: false
              },
              {
                id: "k6TP9oLGgHjl",
                title: "Which of these cities is your favorite?",
                type: "multiple_choice",
                ref: "readable_ref_multiple_choice",
                allow_multiple_selections: false,
                allow_other_choice: false
              },
              {
                id: "RUqkXSeXBXSd",
                title: "Do you have a favorite city we haven't listed?",
                type: "yes_no",
                ref: "readable_ref_yes_no",
                allow_multiple_selections: false,
                allow_other_choice: false
              },
              {
                id: "NRsxU591jIW9",
                title: "How important is the weather to your opinion about a city? 1 is not important, 5 is very important.",
                type: "opinion_scale",
                ref: "readable_ref_opinion_scale",
                allow_multiple_selections: false,
                allow_other_choice: false
              },
              {
                id: "WOTdC00F8A3h",
                title: "How would you rate the weather where you currently live? 1 is poor weather, 5 is excellent weather.",
                type: "rating",
                ref: "readable_ref_rating",
                allow_multiple_selections: false,
                allow_other_choice: false
              },
              {
                id: "pn48RmPazVdM",
                title: "On a scale of 1 to 5, what rating would you give the general quality of life in Sydney? 1 is poor, 5 is excellent",
                type: "number",
                ref: "readable_ref_number2",
                allow_multiple_selections: false,
                allow_other_choice: false
              },
              {
                id: "M5tXK5kG7IeA",
                title: "Book a time with me",
                type: "calendly",
                ref: "readable_ref_calendly",
                properties: {}
              }
            ]
          },
          answers: [
            {
              type: "text",
              text: "It's cold right now! I live in an older medium-sized city with a university. Geographically, the area is hilly.",
              field: {
                id: "DlXFaesGBpoF",
                type: "long_text"
              }
            },
            {
              type: "email",
              email: "laura@example.com",
              field: {
                id: "SMEUb7VJz92Q",
                type: "email"
              }
            },
            {
              type: "text",
              text: "Laura",
              field: {
                id: "JwWggjAKtOkA",
                type: "short_text"
              }
            },
            {
              type: "date",
              date: "2005-10-15",
              field: {
                id: "KoJxDM3c6x8h",
                type: "date"
              }
            },
            {
              type: "choices",
              choices: {
                labels: [
                  "London",
                  "Sydney"
                ]
              },
              field: {
                id: "PNe8ZKBK8C2Q",
                type: "picture_choice"
              }
            },
            {
              type: "number",
              number: 5,
              field: {
                id: "Q7M2XAwY04dW",
                type: "number"
              }
            },
            {
              type: "boolean",
              boolean: true,
              field: {
                id: "gFFf3xAkJKsr",
                type: "legal"
              }
            },
            {
              type: "choice",
              choice: {
                label: "London"
              },
              field: {
                id: "k6TP9oLGgHjl",
                type: "multiple_choice"
              }
            },
            {
              type: "boolean",
              boolean: false,
              field: {
                id: "RUqkXSeXBXSd",
                type: "yes_no"
              }
            },
            {
              type: "number",
              number: 2,
              field: {
                id: "NRsxU591jIW9",
                type: "opinion_scale"
              }
            },
            {
              type: "number",
              number: 3,
              field: {
                id: "WOTdC00F8A3h",
                type: "rating"
              }
            },
            {
              type: "number",
              number: 4,
              field: {
                id: "pn48RmPazVdM",
                type: "number"
              }
            },
            {
              type: "url",
              url: "https://calendly.com/scheduled_events/EVENT_TYPE/invitees/INVITEE",
              field: {
                id: "M5tXK5kG7IeA",
                type: "calendly",
                ref: "readable_ref_calendly"
              }
            }
          ]
        }
      }.with_indifferent_access
    end

    test "sanity" do
      assert @integration.adapter_supports_incoming?
      assert @integration.adapter_incoming_can_defer?
      assert_not @integration.adapter_supports_outgoing?
      assert @integration.adapter_show_alerts?
      assert @integration.adapter_show_logs?
      assert_not @integration.adapter_show_outgoing_webhook_delivery?
    end

    test "adapter_actions" do
      @integration.adapter_incoming_request_params = @create_request
      assert_equal :create, @integration.adapter_action
    end

    test "adapter_thirdparty_id" do
      @integration.adapter_incoming_request_params = @create_request
      assert_equal @create_request.dig("form_response", "token"), @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: [@create_request.dig("form_response", "definition", "title"), @create_request.dig("form_response", "submitted_at")].compact_blank.join(": "),
        urgency: nil,
        thirdparty_id: @create_request.dig("form_response", "token"),
        dedup_keys: [@create_request.dig("form_response", "token")],
        additional_data: []
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
