Rails.application.routes.draw do
   root to: "health#root"
   get "/healthz", to: "health#show"

  namespace :api do
    resources :books, only: [:index, :create, :destroy] do
      resources :notes, only: [:create, :destroy]
      resources :notes_search, only: [:index], path: "notes_search"

      post "notes/bulk", to: "notes_bulk#create"
    end

    namespace :auth do
      resource :session, only: [:create, :destroy]
    end
    resources :users, only: [:create]
  end
  
  if Rails.env.development?
    namespace :api do
      post "debug/db_errors/:kind", to: "debug#db_errors"
    end
  end

end
