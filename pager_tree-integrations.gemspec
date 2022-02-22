require_relative "lib/pager_tree/integrations/version"

Gem::Specification.new do |spec|
  spec.name = "pager_tree-integrations"
  spec.version = PagerTree::Integrations::VERSION
  spec.authors = ["Austin Miller"]
  spec.email = ["amiller@pagertree.com"]
  spec.homepage = "https://pagertree.com"
  spec.summary = "PagerTree Integration Adapters"
  spec.description = "PagerTree Open Source Integration Adapters. Contribute to a growing library of PagerTree integrations!"
  spec.license = "Apache License v2.0"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/PagerTree/pager_tree-integrations"
  spec.metadata["changelog_uri"] = "https://github.com/PagerTree/pager_tree-integrations/blob/master/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.0.1"

  spec.add_development_dependency "standardrb"
  spec.add_development_dependency "vcr"
  spec.add_development_dependency "webmock"
end
