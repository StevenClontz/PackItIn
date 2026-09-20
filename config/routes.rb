Rails.application.routes.draw do
  # Devise lives under /account so that /families is free for the resourceful CRUD below.
  # Only admins create families, so the registration routes (sign-up, cancel, delete account) are skipped;
  # just editing your own account is re-declared below.
  devise_for :families, path: "account", skip: :registrations, controllers: { sessions: "families/sessions" }
  devise_scope :family do
    post "account/sign_in/address", to: "families/sessions#create_with_address", as: :address_family_session
    get "account/edit", to: "devise/registrations#edit", as: :edit_family_registration
    match "account", to: "devise/registrations#update", via: %i[patch put], as: :family_registration
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
