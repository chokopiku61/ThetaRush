Rails.application.routes.draw do
  namespace :admin do
    resources :contests
    resources :contest_problems
    resources :problems
    resources :test_cases

    root to: "contests#index"
  end

  devise_for :users

  get "up" => "rails/health#show", as: :rails_health_check

  get "dashboard", to: "dashboard#show", as: :dashboard
  get "ui_kit", to: "ui_kit#show", as: :ui_kit

  patch "locale", to: "locales#update", as: :locale

  resources :problems, only: [ :index, :show ] do
    resources :submissions, only: [ :create ]
  end
  resources :submissions, only: [ :index, :show ] do
    member do
      get :status
    end
  end

  post "judge0/webhook", to: "judge0_webhook#create"

  resources :contests, only: [ :index, :show ] do
    member do
      get :scoreboard
      post :register
      post :finalize
    end
  end

  get "favorites", to: "favorites#index", as: :favorites
  post "favorites", to: "favorites#create"
  delete "favorites/:id", to: "favorites#destroy", as: :favorite

  resources :groups, only: [ :index, :show, :create ] do
    member do
      post :join
      delete :leave
    end
  end

  resource :profile, only: [ :show ]

  if Rails.env.development?
    require "sidekiq/web"
    mount Sidekiq::Web => "/sidekiq"
  end

  root "home#index"
end
