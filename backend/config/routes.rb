Rails.application.routes.draw do
   get "/healthz", to: "health#show"

  namespace :api do
    resources :books, only: [:index, :create] do
      resources :notes, only: [:create]
      resources :notes_search, only: [:index], path: "notes_search"

      post "notes/bulk", to: "notes_bulk#create"
    end

    resources :notes, only: [:destroy]
  end
  
  if Rails.env.development?
    namespace :api do
      post "debug/db_errors/:kind", to: "debug#db_errors"
    end
  end

end
