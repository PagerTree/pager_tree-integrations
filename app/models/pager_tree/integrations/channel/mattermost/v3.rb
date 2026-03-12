module PagerTree::Integrations
  class Channel::Mattermost::V3 < Channel::Slack::V3
    # we can just piggy back the Channel::Slack::V3 since Mattermost is a clone of Slack
    # both integrations have the same exact functionality

    def _alert_created_at_timestamp_formatted
      _alert.created_at.utc.iso8601.to_s
    end
  end
end
