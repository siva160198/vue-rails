Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  namespace :api do
    namespace :v1 do
      get "status", to: "status#show"
      get "readiness", to: "readiness#show"
      get "csrf", to: "csrf#show"
      resource :password_reset, only: %i[show create update]
      resource :registration, only: :create
      resource :session, only: %i[show create destroy] do
        post :verify_otp
        post :resend_otp
      end
      resources :sessions, only: %i[index destroy], controller: :devices do
        delete :others, on: :collection, action: :destroy_others
      end
      resource :profile, only: %i[update destroy] do
        post :recovery_codes
      end

      namespace :admin do
        get "dashboard", to: "dashboard#show"
        resources :users, only: %i[index show update]
        resources :roles, only: %i[index show create update destroy]
        resources :audit_logs, only: :index
        resources :jobs, only: %i[index destroy] do
          post :retry, on: :member
        end
        resource :api_docs, only: :show
      end
    end
  end

  match "/api/*unmatched", to: "api_errors#not_found", via: :all

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "*path", to: "spa#index", constraints: ->(request) do
    !request.path.start_with?("/api", "/rails", "/letter_opener", "/frontend")
  end
  root "spa#index"

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
