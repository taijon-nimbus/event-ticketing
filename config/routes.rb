Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :events, only: [:index, :show]
      resources :orders, only: [:create, :index]
    end
  end
end
