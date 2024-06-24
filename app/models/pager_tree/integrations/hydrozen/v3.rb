module PagerTree::Integrations
  class Hydrozen::V3 < SixtySixUptime::V3
    # we can just piggy back the SixtySixUptime::V3 since Hydrozen is a clone of SixtySixUptime
    # both integrations have the same exact functionality
  end
end
