module PagerTree
  module Integrations
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
