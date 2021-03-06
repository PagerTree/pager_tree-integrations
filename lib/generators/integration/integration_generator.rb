class IntegrationGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  def copy_templates
    template "model.rb.tt", "app/models/#{file_path}.rb"
    template "_form_options.html.erb.tt", "app/views/#{file_path}/_form_options.html.erb"
    template "_show_options.html.erb.tt", "app/views/#{file_path}/_show_options.html.erb"
    template "test.rb.tt", "test/models/#{file_path}_test.rb"
  end

  def inject_locales
    puts "IMPORTANT (1): Ensure you add your translations to config/locales/en.yml"
    puts "IMPORTANT (2): Ensure you add your test fixtures to test/fixtures/pager_tree/integration/integrations.yml"
  end
end
