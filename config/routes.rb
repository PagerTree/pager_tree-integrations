PagerTree::Integrations::Engine.routes.draw do
  namespace :live_call_routing do
    namespace :twilio do
      resources :v3, only: [], controller: "v3" do
        member do
          get :music
          post :queue_status
        end
      end
    end
  end
end
