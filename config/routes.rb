Rails.application.routes.draw do
  # Devise only handles signing in and out (under /account, so /families is free for the resourceful CRUD
  # below). Families are created and edited, by admins and by the family itself, through FamiliesController.
  devise_for :families, path: "account", controllers: { sessions: "families/sessions" }
  devise_scope :family do
    post "account/sign_in/address", to: "families/sessions#create_with_address", as: :address_family_session
  end
  resources :families do
    resources :people, shallow: true
    resource :account, only: :show
  end
  resources :funds
  resources :ledger_transactions, only: %i[new create]
  resources :events do
    resource :rsvp, only: :update
  end

  root "home#index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
