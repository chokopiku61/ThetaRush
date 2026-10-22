Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "dashboard", to: "dashboard#show", as: :dashboard
  get "ui_kit", to: "ui_kit#show", as: :ui_kit

  resources :problems, only: [ :index, :show ] do
    resources :submissions, only: [ :create ]
  end
  resources :submissions, only: [ :show ]

  post "judge0/webhook", to: "judge0_webhook#create"

  resources :contests, only: [ :index, :show ] do
    member do
      get :scoreboard
      post :register
    end
  end

  resource :profile, only: [ :show ]

  if Rails.env.development?
    require "sidekiq/web"
    mount Sidekiq::Web => "/sidekiq"
  end

  # Defines the root path route ("/")
  root "home#index"
end
