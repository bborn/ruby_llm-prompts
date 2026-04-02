RubyLLM::Prompts::Engine.routes.draw do
  root to: "prompts#index"

  resources :prompts, param: :slug do
    member do
      get :versions
      post :rollback
      get :playground
      post :playground, action: :execute_playground
    end
  end
end
