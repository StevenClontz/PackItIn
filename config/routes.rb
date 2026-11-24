Rails.application.routes.draw do
  # Devise handles password sign-in and sign-out (under /account, so /families is free for the resourceful CRUD
  # below). Families are created and edited, by admins and by the family itself, through FamiliesController.
  devise_for :families, path: "account", controllers: { passwords: "families/passwords" }
  devise_scope :family do
    post "account/sign_in/email", to: "families/email_logins#create", as: :email_login
    get "account/sign_in/code", to: "families/email_logins#code", as: :email_login_code
    post "account/sign_in/code", to: "families/email_logins#verify_code"
    get "account/sign_in/email/:token", to: "families/email_logins#link", as: :email_login_link
    post "account/sign_in/email/:token", to: "families/email_logins#use_link"
  end
  resources :families do
    resources :people, shallow: true, except: :index do
      resources :leaderships, only: %i[create destroy]
    end
    resource :account, only: :show
  end
  resources :funds
  resources :ledger_transactions, only: %i[new create]
  resources :events do
    resource :rsvp, only: :update
    resource :payment, only: :create, controller: "event_payments"
    resource :account, only: :show
    resource :announcement, only: %i[new create], controller: "event_announcements"
    resources :rsvp_options, except: %i[index show]
  end
  resource :dens, only: :show
  get "calendar.ics", to: "calendars#show", as: :calendar, format: false, defaults: { format: :ics }
  patch "people/:id/notifications", to: "notification_preferences#update", as: :person_notifications

  # One-click unsubscribe from pack email. GET only shows a confirmation (mail scanners follow links);
  # POST unsubscribes, as does the RFC 8058 List-Unsubscribe-Post request mail clients send.
  get "unsubscribe/:token", to: "unsubscribes#show", as: :unsubscribe
  post "unsubscribe/:token", to: "unsubscribes#create"
  delete "unsubscribe/:token", to: "unsubscribes#destroy"
  # ActiveStorage direct uploads for the event description editor, limited to people who can create events.
  post "event_uploads", to: "event_uploads#create", as: :event_uploads

  root "home#index"

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
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
