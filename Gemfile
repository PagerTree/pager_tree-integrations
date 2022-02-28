source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in pager_tree-integrations.gemspec.
gemspec

gem "sprockets-rails"

gem "appraisal", "~> 2.4"

group :development, :test do
  gem "dotenv-rails", "~> 2.7" # .env files
  # Start debugger with binding.b [https://github.com/ruby/debug]
  gem "debug", ">= 1.0.0"
  gem "vcr", "~> 6.0"
end

gem "pg", "~> 1.3"

# integration dependencies
gem "aws-sdk-sns", "~> 1.53"
gem "deferred_request", "~> 1.0"
gem "httparty", "~> 0.20.0"
gem "sanitize", "~> 6.0"
gem "twilio-ruby", "~> 5.64"
gem "ulid", "~> 1.3"
gem "validate_url", "~> 1.0"
