module PagerTree
  module Integrations
    module ApplicationHelper
      def mask(string, all_but = 4, char = "*")
        string&.gsub(/.(?=.{#{all_but}})/, char)
      end
    end
  end
end
