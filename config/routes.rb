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
    resources :students, controller: "organizations/students", only: %i[index show]
    resources :roles, controller: "organizations/roles", except: :show
    resources :courses, controller: "organizations/courses" do
      resources :materials, controller: "organizations/materials" do
        patch :toggle_completion, on: :member
      end
      resources :quizzes, controller: "organizations/quizzes" do
        get :attempt, on: :member, controller: "organizations/quiz_attempts"
        patch "attempt/questions/:question_id", to: "organizations/quiz_attempts#update_answer", as: :attempt_answer
        resources :questions, controller: "organizations/quiz_questions", only: %i[create update destroy] do
          patch :move, on: :member
        end
      end
      member do
        get :enrollments
        patch :enrollments, action: :update_enrollments
        patch "contents/:content_id/move", action: :move_content, as: :move_content
      end
    end
    get "grading", to: "organizations/quiz_attempt_reviews#index", as: :grading
    get "grading/attempts/:id", to: "organizations/quiz_attempt_reviews#show", as: :grading_attempt
    patch "grading/attempts/:id/review", to: "organizations/quiz_attempt_reviews#review", as: :review_grading_attempt
    patch "grading/attempts/:id/unreview", to: "organizations/quiz_attempt_reviews#unreview", as: :unreview_grading_attempt
    patch "grading/attempts/:id/questions/:question_id", to: "organizations/quiz_attempt_reviews#grade_answer", as: :grade_answer
    delete "grading/attempts/:id/questions/:question_id/grade", to: "organizations/quiz_attempt_reviews#reset_grade", as: :reset_answer_grade
    delete "grading/attempts/:id", to: "organizations/quiz_attempt_reviews#reset", as: :reset_grading_attempt
    get "evaluation", to: "organizations/evaluations#index", as: :evaluation
    get "evaluation/attempts/:id", to: "organizations/evaluations#show", as: :evaluation_attempt
    resources :audit_events, controller: "organizations/audit_events", only: :index
  end

  namespace :console do
    root "dashboard#show"
    resources :organizations, param: :slug, except: %i[show destroy] do
      patch :toggle_status, on: :member
    end
    resources :users, except: :show do
      post :send_password_reset, on: :member
    end
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
