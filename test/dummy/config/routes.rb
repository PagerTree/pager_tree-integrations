Rails.application.routes.draw do
  mount PagerTree::Integrations::Engine => "/pager_tree-integrations"
end
