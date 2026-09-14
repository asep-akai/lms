Rails.application.routes.draw do
  devise_for :users, skip: [ :registrations ], controllers: { registrations: "users/registrations" }
  devise_scope :user do
    get "users/edit" => "users/registrations#edit", as: :edit_user_registration
    patch "users" => "users/registrations#update", as: :user_registration
  end

  devise_for :admins,
    path: "console",
    path_names: { sign_in: "login", sign_out: "logout" },
    skip: [ :registrations ],
    controllers: { sessions: "console/sessions", passwords: "console/passwords" }

  root "dashboard#index"

  resources :organizations, param: :slug, only: %i[index show edit update] do
    resources :memberships, controller: "organizations/memberships", except: :show
    resources :roles, controller: "organizations/roles", except: :show
    resources :audit_events, controller: "organizations/audit_events", only: :index
  end

  namespace :console do
    root "dashboard#show"
    resources :organizations, except: :show
    resources :users, except: :show
    resources :admins, except: :show
    resources :roles, except: :show
  end
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
