Rails.application.routes.draw do
  devise_for :users

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root path
  root "dashboard#index"

  # Dashboard
  get "dashboard", to: "dashboard#index"

  # Campaigns
  resources :campaigns do
    member do
      get :preview
      post :send_campaign
      post :send_test
      post :pause
      post :resume
      post :stop
      post :duplicate
    end

    collection do
      post :bulk_send
      post :bulk_schedule
      get :dashboard
    end
  end

  # Contacts
  resources :contacts do
    collection do
      get :import
      post :import
      get :export
    end
  end

  # Templates
  resources :templates do
    member do
      get :preview
      post :duplicate
    end
  end

  # Tags
  resources :tags

  # Analytics
  get "analytics", to: "analytics#index"
  get "analytics/campaigns", to: "analytics#campaigns"
  get "analytics/contacts", to: "analytics#contacts"
  get "analytics/export", to: "analytics#export"

  # Account management
  resource :account, only: [ :show, :edit, :update ] do
    get :billing
    get :team
    post :invite_user
    delete :remove_user
    delete :cancel_invitation
    get :settings
    patch :update_settings
  end

  # Email tracking (for open/click tracking)
  get "track/open/:token", to: "email_tracking#open", as: :track_email_open
  get "track/click/:token", to: "email_tracking#click", as: :track_email_click
  get "unsubscribe/:token", to: "email_tracking#unsubscribe", as: :unsubscribe
end
