Rails.application.routes.draw do
  root "pages#home"

  # 言い換え機能の最小構成（一覧表示 + 作成）
  resources :rephrases, only: %i[index create]
  delete "rephrases/history/:id", to: "rephrases#destroy_history", as: :rephrase_history
  delete "rephrases/history", to: "rephrases#clear_history", as: :clear_rephrase_history

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
