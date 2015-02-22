Spree::Core::Engine.routes.draw do
#Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    resources :promotions, only: [:show, :create, :update]
  end
end
