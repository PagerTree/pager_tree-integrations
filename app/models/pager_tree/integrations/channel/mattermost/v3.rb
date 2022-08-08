module PagerTree::Integrations
  class Channel::Mattermost::V3 < Channel::Slack::V3
    # we can just piggy back the Channel::Slack::V3 since Mattermost is a clone of Slack
    # both integrations have the same exact functionality
  end
end
