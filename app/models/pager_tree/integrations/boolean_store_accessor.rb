# https://gist.github.com/ozgun/e062ff629708286f7211
# File: app/models/concerns/boolean_store_accessor.rb
#
# When we submit a form in order to update a model, a booelan/checkbox field is posted
# as '1' or '0', and if we are using ActiveRecord::Store, posted value is stored in
# database as '1' or '0'.  By the help of this module, we store '1' and '0'
# values as `true` or `false`.
#
# Example usage:
#
# ```
# class Page < ActiveRecord::Base
#   extend BooleanStoreAccessor
#   store :settings, accessors: [:hide_from_navigation]
#   boolean_store_accessor :hide_from_navigation
# end
#
# page = Page.first
# page.hide_from_navigation? #=> false
# page.hide_from_navigation = true
# page.save
# page.hide_from_navigation? #=> true
# page.settings #=> {"hide_from_navigation"=>true}
# ```
#
module PagerTree::Integrations::BooleanStoreAccessor
  def boolean_store_accessor(attr_name)
    define_method "#{attr_name}=".to_sym do |value|
      values = ["1", true]
      super(values.include?(value))
    end

    define_method attr_name do
      values = [nil, false, "0"]
      !values.include?(super())
    end

    define_method "#{attr_name}?".to_sym do
      send(attr_name)
    end
  end
end
