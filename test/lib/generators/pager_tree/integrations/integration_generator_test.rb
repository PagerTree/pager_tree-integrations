require "test_helper"
require "generators/integration/integration_generator"

module PagerTree::Integrations
  class IntegrationGeneratorTest < Rails::Generators::TestCase
    tests IntegrationGenerator
    destination Rails.root.join("tmp/generators")
    setup :prepare_destination

    test "generator runs without errors" do
      assert_nothing_raised do
        run_generator ["test/v3"]
      end
    end
  end
end
