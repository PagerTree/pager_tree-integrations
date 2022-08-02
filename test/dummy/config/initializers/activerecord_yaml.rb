if Gem::Version.new(Rails.version) >= Gem::Version.new("7.0.3.1")
  ActiveRecord.yaml_column_permitted_classes = [ActiveSupport::HashWithIndifferentAccess]
end
