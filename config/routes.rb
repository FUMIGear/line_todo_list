Rails.application.routes.draw do
  resources :tasks
  # resources :line_bot #これを実行すると、CRUDのURLが作られる。（そこまでいらない）
  # get "/", to: 'tasks#index', as: :tasks
  root 'tasks#index'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  # post 'line_bot/callback' #お！フィーリングで追加できた。
  post 'callback' => 'line_bot#callback' #課題はこっちぽい。
end
