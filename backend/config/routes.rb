Rails.application.routes.draw do
  namespace :api do
    resources :books, only: [:index, :create] do
      resources :notes, only: [:index, :create]

      post "notes/bulk", to: "notes_bulk#create"
    end

    resources :notes, only: [:destroy]
  end
end
