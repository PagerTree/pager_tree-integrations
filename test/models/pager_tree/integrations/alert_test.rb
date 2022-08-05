require "test_helper"

module PagerTree::Integrations
  class AlertTest < ActiveSupport::TestCase
    setup do
      @valid_alert = Alert.new(
        title: "Simple Alert",
        description: "This is a simple alert",
        urgency: "low",
        incident: true,
        incident_severity: "SEV-1",
        incident_message: "This is a test incident message",
        meta: {
          foo: "bar"
        },
        thirdparty_id: "12345",
        dedup_keys: ["foo", "bar"],
        additional_data: [],
        attachments: []
      )
    end

    test "sanity" do
      assert_equal "Simple Alert", @valid_alert.title
      assert_equal "This is a simple alert", @valid_alert.description
      assert_equal "low", @valid_alert.urgency
      assert_equal true, @valid_alert.incident?
      assert_equal "SEV-1", @valid_alert.incident_severity
      assert_equal "This is a test incident message", @valid_alert.incident_message
      assert_equal "12345", @valid_alert.thirdparty_id
      assert_equal ["foo", "bar"], @valid_alert.dedup_keys
      assert_equal [], @valid_alert.additional_data
      assert_equal [], @valid_alert.attachments
    end

    test "defaults" do
      alert = Alert.new
      assert_nil alert.title
      assert_nil alert.description
      assert_nil alert.urgency
      assert_not alert.incident?
      assert_nil alert.incident_severity
      assert_nil alert.incident_message
      assert_nil alert.thirdparty_id
      assert_equal [], alert.dedup_keys
      assert_equal [], alert.additional_data
      assert_equal [], alert.attachments
    end

    test "validations" do
      assert @valid_alert.valid?

      clone = @valid_alert.dup
      clone.title = nil
      assert_not clone.valid?

      clone = @valid_alert.dup
      clone.urgency = "foo"
      assert_not clone.valid?

      clone = @valid_alert.dup
      clone.incident = "foo"
      assert_not clone.valid?

      clone = @valid_alert.dup
      clone.incident = true
      clone.incident_severity = nil
      assert_not clone.valid?

      clone = @valid_alert.dup
      clone.thirdparty_id = nil
      assert_not clone.valid?

      clone = @valid_alert.dup
      clone.urgency = "not_an_urgency"
      assert_not clone.valid?

      clone = @valid_alert.dup
      clone.incident_severity = "not_a_severity"
      assert_not clone.valid?
    end
  end
end
