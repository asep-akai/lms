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

  root "landing#home"
  get "app", to: "dashboard#index", as: :user_root
  get "welcome", to: "landing#show", as: :landing
  get "welcome/assets/:id", to: "landing#asset", as: :landing_asset

  resources :organizations, param: :slug, only: %i[index show edit update] do
    resources :memberships, controller: "organizations/memberships", except: :show
    resources :students, controller: "organizations/students", only: %i[index show] do
      get :enrollment, on: :member
      post :enroll, on: :member
      get :reschedule_quota, on: :member
      patch :reschedule_quota, action: :update_reschedule_quota, on: :member
    end
    resources :roles, controller: "organizations/roles", except: :show
    resources :class_meetings, path: "classes", controller: "organizations/class_meetings" do
      post :request_reschedule, on: :member
      get :history, on: :collection
      get "calendar/:date", action: :day, on: :collection, as: :calendar_day
      resources :feedbacks, controller: "organizations/class_meeting_feedbacks", only: %i[index show new create]
    end
    get "class-feedback", to: "organizations/class_meeting_feedbacks#admin_index", as: :class_feedback
    resources :certificates, controller: "organizations/certificates", only: %i[index show] do
      patch :unpublish, on: :member
    end
    resources :assignments, controller: "organizations/assignments", only: %i[index show new create edit update] do
      get :document, action: :download_document, on: :member
      patch :cancel, on: :member
      resource :submission, controller: "organizations/assignment_submissions", only: :update
      get "submissions/:submission_id/documents/:attachment_id",
        to: "organizations/assignment_submissions#download_document",
        as: :submission_document
      patch "recipients/:recipient_id/comment", to: "organizations/assignment_submissions#comment", as: :recipient_comment
    end
    resources :courses, controller: "organizations/courses" do
      resources :sections, controller: "organizations/course_sections", except: :show do
        patch :move, on: :member
      end
      resources :materials, controller: "organizations/materials" do
        patch :toggle_completion, on: :member
      end
      resources :quizzes, controller: "organizations/quizzes" do
        get :attempt, on: :member, controller: "organizations/quiz_attempts"
        post :retake, on: :member, controller: "organizations/quiz_attempts"
        get :connection_check, on: :member
        patch "attempt/questions/:question_id", to: "organizations/quiz_attempts#update_answer", as: :attempt_answer
        resources :pages, controller: "organizations/quiz_pages", only: %i[create update destroy] do
          patch :move, on: :member
        end
        resources :questions, controller: "organizations/quiz_questions", only: %i[create update destroy] do
          patch :move, on: :member
        end
      end
      member do
        get :enrollments
        patch :enrollments, action: :update_enrollments
        patch "contents/:content_id/move", action: :move_content, as: :move_content
        patch "contents/:content_id/section", action: :move_content_to_section, as: :move_content_to_section
      end
    end
    get "grading", to: "organizations/quiz_attempt_reviews#index", as: :grading
    get "grading/attempts/:id", to: "organizations/quiz_attempt_reviews#show", as: :grading_attempt
    post "grading/attempts/:attempt_id/certificate", to: "organizations/certificates#create", as: :grading_attempt_certificate
    post "grading/attempts/:id/automatic", to: "organizations/quiz_attempt_reviews#automatic_grade", as: :automatic_grade_attempt
    patch "grading/attempts/:id/feedback", to: "organizations/quiz_attempt_reviews#update_feedback", as: :grading_attempt_feedback
    patch "grading/attempts/:id/review", to: "organizations/quiz_attempt_reviews#review", as: :review_grading_attempt
    patch "grading/attempts/:id/unreview", to: "organizations/quiz_attempt_reviews#unreview", as: :unreview_grading_attempt
    patch "grading/attempts/:id/questions/:question_id", to: "organizations/quiz_attempt_reviews#grade_answer", as: :grade_answer
    patch "grading/attempts/:id/questions/:question_id/feedback", to: "organizations/quiz_attempt_reviews#update_answer_feedback", as: :answer_feedback
    delete "grading/attempts/:id/questions/:question_id/grade", to: "organizations/quiz_attempt_reviews#reset_grade", as: :reset_answer_grade
    delete "grading/attempts/:id", to: "organizations/quiz_attempt_reviews#reset", as: :reset_grading_attempt
    get "evaluation", to: "organizations/evaluations#index", as: :evaluation
    get "evaluation/attempts/:id", to: "organizations/evaluations#show", as: :evaluation_attempt
    resources :audit_events, controller: "organizations/audit_events", only: :index
    resources :support_tickets, controller: "organizations/support_tickets", only: %i[index show new create update] do
      post :reply, on: :member
      patch :escalate, on: :member
      get "attachments/:attachment_id", action: :download_attachment, on: :member, as: :attachment
    end
    resources :direct_conversations, path: "messages", controller: "organizations/direct_conversations", only: %i[index show create] do
      resources :direct_messages, path: "replies", controller: "organizations/direct_messages", only: :create
    end
    resources :notifications, controller: "organizations/notifications", only: %i[index show] do
      patch :mark_all_read, on: :collection
    end
  end

  namespace :console do
    root "dashboard#show"
    resource :website, only: %i[show update], controller: "website" do
      get :preview
      get "assets/:id", action: :asset, as: :asset
      post :publish
      delete :unpublish
      resources :sections, controller: "website_sections", except: %i[index show] do
        patch :move, on: :member
      end
      resources :navigation_items, controller: "website_navigation_items", except: %i[index show] do
        patch :move, on: :member
      end
    end
    resources :organizations, param: :slug, except: %i[show destroy] do
      patch :toggle_status, on: :member
    end
    resources :users, except: :show do
      post :send_password_reset, on: :member
    end
    resources :admins, except: :show
    resources :roles, except: :show
    resources :support_tickets, only: %i[index show update] do
      post :reply, on: :member
      get "attachments/:attachment_id", action: :download_attachment, on: :member, as: :attachment
    end
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
