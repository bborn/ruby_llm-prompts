RubyLLM::Prompts::Engine.routes.draw do
  root to: "prompts#index"

  resources :prompts, param: :slug do
    member do
      get :versions
      post :rollback
    end
  end
end
