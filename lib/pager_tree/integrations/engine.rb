module PagerTree
  module Integrations
    class Engine < ::Rails::Engine
      isolate_namespace PagerTree::Integrations
    end
  end
end
