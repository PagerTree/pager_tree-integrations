require "test_helper"

module PagerTree::Integrations
  class AwsCloudwatch::V3Test < ActiveSupport::TestCase
    include Integrateable

    setup do
      @integration = pager_tree_integrations_integrations(:aws_cloudwatch_v3)

      @create_request = {
        Type: "Notification",
        MessageId: "836fe1ec-79e0-56b8-827f-b66569e37e11",
        TopicArn: "arn:aws:sns:us-east-1:498849832712:update-cherwell-cmdb",
        Message: "{\r\n   \"AlarmName\":\"Saffron-Octopus-RDS\",\r\n   \"AlarmDescription\":null,\r\n   \"AWSAccountId\":\"498849832712\",\r\n   \"NewStateValue\":\"ALARM\",\r\n   \"NewStateReason\":\"Threshold Crossed: 1 datapoint [2.1533759377604764 (20\/07\/20 21:07:00)] was greater than or equal to the threshold (0.0175).\",\r\n   \"StateChangeTime\":\"2020-07-20T21:12:01.544+0000\",\r\n   \"Region\":\"US East (N. Virginia)\",\r\n   \"AlarmArn\":\"arn:aws:cloudwatch:us-east-1:498849832712:alarm:Saffron-Octopus-RDS\",\r\n   \"OldStateValue\":\"INSUFFICIENT_DATA\",\r\n   \"Trigger\":{\r\n      \"MetricName\":\"CPUUtilization\",\r\n      \"Namespace\":\"AWS\/RDS\",\r\n      \"StatisticType\":\"Statistic\",\r\n      \"Statistic\":\"AVERAGE\",\r\n      \"Unit\":null,\r\n      \"Dimensions\":[\r\n         {\r\n            \"value\":\"sm16lm1jrrjf0rk\",\r\n            \"name\":\"DBInstanceIdentifier\"\r\n         }\r\n      ],\r\n      \"Period\":300,\r\n      \"EvaluationPeriods\":1,\r\n      \"ComparisonOperator\":\"GreaterThanOrEqualToThreshold\",\r\n      \"Threshold\":0.0175,\r\n      \"TreatMissingData\":\"\",\r\n      \"EvaluateLowSampleCountPercentile\":\"\"\r\n   }\r\n}",
        Timestamp: "2020-07-15T14:08:03.824Z",
        SignatureVersion: "1",
        Signature: "JNdxahPfT0tVsX8+ZVPeA23M09UcCbIQ8uar5AZ4VqscGhzqpMcy4v00mluwr3eyJuFsogxhv1RprFIHU0ZH4bNRWxDpzdVnFIGVSnSBZDVi075ynf+oxagTLhSs7aa9Aar38RcQicaYBc6kHiCg5FHIwwU1OXeehVjHavFKC1ymSegaxtD2pUG4jST30gC2P55I+qyFItPOj+Ih8ZqRBXc3H989mwDKU0Qa54/lQ0cFMC8YwZcQzqwSoZQwIvsrCzLjNR7l2IIEq4pk9d2thq9C/tySFNlXd4/HP/Vd6I9wuP08c0nspmmWxQY1X7CQOvwKway7V9WmKVpku3avxQ==",
        SigningCertURL: "https://sns.us-east-1.amazonaws.com/SimpleNotificationService-a86cb10b4e1f29c941702d737128f7b6.pem",
        UnsubscribeURL: "https://sns.us-east-1.amazonaws.com/?Action=Unsubscribe&SubscriptionArn=arn:aws:sns:us-east-1:498849832712:update-cherwell-cmdb:e0cff011-7a6a-4425-9c0c-e812474debe5"
      }.with_indifferent_access

      @resolve_request = {
        Type: "Notification",
        MessageId: "836fe1ec-79e0-56b8-827f-b66569e37e11",
        TopicArn: "arn:aws:sns:us-east-1:498849832712:update-cherwell-cmdb",
        Message: "{\r\n   \"AlarmName\":\"Saffron-Octopus-RDS\",\r\n   \"AlarmDescription\":null,\r\n   \"AWSAccountId\":\"498849832712\",\r\n   \"NewStateValue\":\"OK\",\r\n   \"NewStateReason\":\"Threshold Crossed: 1 datapoint [2.1533759377604764 (20\/07\/20 21:07:00)] was greater than or equal to the threshold (0.0175).\",\r\n   \"StateChangeTime\":\"2020-07-20T21:12:01.544+0000\",\r\n   \"Region\":\"US East (N. Virginia)\",\r\n   \"AlarmArn\":\"arn:aws:cloudwatch:us-east-1:498849832712:alarm:Saffron-Octopus-RDS\",\r\n   \"OldStateValue\":\"INSUFFICIENT_DATA\",\r\n   \"Trigger\":{\r\n      \"MetricName\":\"CPUUtilization\",\r\n      \"Namespace\":\"AWS\/RDS\",\r\n      \"StatisticType\":\"Statistic\",\r\n      \"Statistic\":\"AVERAGE\",\r\n      \"Unit\":null,\r\n      \"Dimensions\":[\r\n         {\r\n            \"value\":\"sm16lm1jrrjf0rk\",\r\n            \"name\":\"DBInstanceIdentifier\"\r\n         }\r\n      ],\r\n      \"Period\":300,\r\n      \"EvaluationPeriods\":1,\r\n      \"ComparisonOperator\":\"GreaterThanOrEqualToThreshold\",\r\n      \"Threshold\":0.0175,\r\n      \"TreatMissingData\":\"\",\r\n      \"EvaluateLowSampleCountPercentile\":\"\"\r\n   }\r\n}",
        Timestamp: "2020-07-15T14:08:03.824Z",
        SignatureVersion: "1",
        Signature: "JNdxahPfT0tVsX8+ZVPeA23M09UcCbIQ8uar5AZ4VqscGhzqpMcy4v00mluwr3eyJuFsogxhv1RprFIHU0ZH4bNRWxDpzdVnFIGVSnSBZDVi075ynf+oxagTLhSs7aa9Aar38RcQicaYBc6kHiCg5FHIwwU1OXeehVjHavFKC1ymSegaxtD2pUG4jST30gC2P55I+qyFItPOj+Ih8ZqRBXc3H989mwDKU0Qa54/lQ0cFMC8YwZcQzqwSoZQwIvsrCzLjNR7l2IIEq4pk9d2thq9C/tySFNlXd4/HP/Vd6I9wuP08c0nspmmWxQY1X7CQOvwKway7V9WmKVpku3avxQ==",
        SigningCertURL: "https://sns.us-east-1.amazonaws.com/SimpleNotificationService-a86cb10b4e1f29c941702d737128f7b6.pem",
        UnsubscribeURL: "https://sns.us-east-1.amazonaws.com/?Action=Unsubscribe&SubscriptionArn=arn:aws:sns:us-east-1:498849832712:update-cherwell-cmdb:e0cff011-7a6a-4425-9c0c-e812474debe5"
      }.with_indifferent_access

      @other_request = {
        Type: "Notification",
        MessageId: "836fe1ec-79e0-56b8-827f-b66569e37e11",
        TopicArn: "arn:aws:sns:us-east-1:498849832712:update-cherwell-cmdb",
        Message: "{\r\n   \"AlarmName\":\"Saffron-Octopus-RDS\",\r\n   \"AlarmDescription\":null,\r\n   \"AWSAccountId\":\"498849832712\",\r\n   \"NewStateValue\":\"UNKNOW\",\r\n   \"NewStateReason\":\"Threshold Crossed: 1 datapoint [2.1533759377604764 (20\/07\/20 21:07:00)] was greater than or equal to the threshold (0.0175).\",\r\n   \"StateChangeTime\":\"2020-07-20T21:12:01.544+0000\",\r\n   \"Region\":\"US East (N. Virginia)\",\r\n   \"AlarmArn\":\"arn:aws:cloudwatch:us-east-1:498849832712:alarm:Saffron-Octopus-RDS\",\r\n   \"OldStateValue\":\"INSUFFICIENT_DATA\",\r\n   \"Trigger\":{\r\n      \"MetricName\":\"CPUUtilization\",\r\n      \"Namespace\":\"AWS\/RDS\",\r\n      \"StatisticType\":\"Statistic\",\r\n      \"Statistic\":\"AVERAGE\",\r\n      \"Unit\":null,\r\n      \"Dimensions\":[\r\n         {\r\n            \"value\":\"sm16lm1jrrjf0rk\",\r\n            \"name\":\"DBInstanceIdentifier\"\r\n         }\r\n      ],\r\n      \"Period\":300,\r\n      \"EvaluationPeriods\":1,\r\n      \"ComparisonOperator\":\"GreaterThanOrEqualToThreshold\",\r\n      \"Threshold\":0.0175,\r\n      \"TreatMissingData\":\"\",\r\n      \"EvaluateLowSampleCountPercentile\":\"\"\r\n   }\r\n}",
        Timestamp: "2020-07-15T14:08:03.824Z",
        SignatureVersion: "1",
        Signature: "JNdxahPfT0tVsX8+ZVPeA23M09UcCbIQ8uar5AZ4VqscGhzqpMcy4v00mluwr3eyJuFsogxhv1RprFIHU0ZH4bNRWxDpzdVnFIGVSnSBZDVi075ynf+oxagTLhSs7aa9Aar38RcQicaYBc6kHiCg5FHIwwU1OXeehVjHavFKC1ymSegaxtD2pUG4jST30gC2P55I+qyFItPOj+Ih8ZqRBXc3H989mwDKU0Qa54/lQ0cFMC8YwZcQzqwSoZQwIvsrCzLjNR7l2IIEq4pk9d2thq9C/tySFNlXd4/HP/Vd6I9wuP08c0nspmmWxQY1X7CQOvwKway7V9WmKVpku3avxQ==",
        SigningCertURL: "https://sns.us-east-1.amazonaws.com/SimpleNotificationService-a86cb10b4e1f29c941702d737128f7b6.pem",
        UnsubscribeURL: "https://sns.us-east-1.amazonaws.com/?Action=Unsubscribe&SubscriptionArn=arn:aws:sns:us-east-1:498849832712:update-cherwell-cmdb:e0cff011-7a6a-4425-9c0c-e812474debe5"
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

    test "adapter_actions create" do
      @integration.adapter_incoming_request_params = @create_request
      assert_equal :create, @integration.adapter_action
    end

    test "adapter_actions resolve" do
      @integration.adapter_incoming_request_params = @resolve_request
      assert_equal :resolve, @integration.adapter_action
    end

    test "adapter_actions other" do
      @integration.adapter_incoming_request_params = @other_request
      assert_equal :other, @integration.adapter_action
    end

    test "adapter_thirdparty_id" do
      @integration.adapter_incoming_request_params = @create_request
      assert_equal "arn:aws:sns:us-east-1:498849832712:update-cherwell-cmdb:Saffron-Octopus-RDS", @integration.adapter_thirdparty_id
    end

    test "adapter_process_create" do
      @integration.adapter_incoming_request_params = @create_request

      true_alert = Alert.new(
        title: "Saffron-Octopus-RDS",
        description: "Threshold Crossed: 1 datapoint [2.1533759377604764 (20/07/20 21:07:00)] was greater than or equal to the threshold (0.0175).",
        urgency: nil,
        thirdparty_id: "arn:aws:sns:us-east-1:498849832712:update-cherwell-cmdb:Saffron-Octopus-RDS",
        dedup_keys: [],
        additional_data: [
          AdditionalDatum.new(format: "text", label: "AWS Account ID", value: "498849832712"),
          AdditionalDatum.new(format: "text", label: "Region", value: "US East (N. Virginia)"),
          AdditionalDatum.new(format: "text", label: "Alarm ARN", value: "arn:aws:cloudwatch:us-east-1:498849832712:alarm:Saffron-Octopus-RDS"),
          AdditionalDatum.new(format: "datetime", label: "State Change Time", value: "2020-07-20T21:12:01.544+0000")
        ]
      )

      assert_equal true_alert.to_json, @integration.adapter_process_create.to_json
    end
  end
end
