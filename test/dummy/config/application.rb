require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)
require "pager_tree/integrations"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f

    # For compatibility with applications that use this config
    config.action_controller.include_all_helpers = false

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Just copied from https://guides.rubyonrails.org/active_record_encryption.html#setup
    config.active_record.encryption.primary_key = "EGY8WhulUOXixybod7ZWwMIL68R9o5kC"
    config.active_record.encryption.deterministic_key = "aPA5XyALhf75NNnMzaspW7akTfZp0lPY"
    config.active_record.encryption.key_derivation_salt = "xEY0dt6TZcAMg52K7O84wYzkjvbA62Hz"
    config.active_record.encryption.encrypt_fixtures = true
  end
end
