# PagerTree::Integrations
PagerTree Open Source Integration Adapters. Contribute to a growing library of PagerTree integrations!

## Add An Integration
1. Fork the project
1. Create a new branch (ex: "integration-pingdom")
1. Add your changes
1. Test your changes
1. Run standardrb
1. If all tests are passing, create a pull request

Please see [CREATING_AN_INTEGRATION](CREATING_AN_INTEGRATION.md) for details instructions on how to create a new integration.

## Usage
Please see [CONFIGURATION](CONFIGURATION.md) for details on configuration options for the main app.

## Installation
Add this line to your application's Gemfile:

```ruby
gem "pager_tree-integrations"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install pager_tree-integrations
```

### Migrations
Copy the migrations to your app:

```bash
bin/rails pager_tree_integrations:install:migrations
```

Then, run the migrations:

```bash
bin/rails db:migrate
```

## 🙏 Contributing

If you have an issue you'd like to submit, please do so using the issue tracker in GitHub. In order for us to help you in the best way possible, please be as detailed as you can.

If you'd like to open a PR please make sure the following things pass:

```ruby
bin/rails db:test:prepare
bin/rails test
bundle exec standardrb
```


## 📝 License
The gem is available as open source under the terms of the [Apache License v2.0](https://opensource.org/licenses/Apache-2.0).
