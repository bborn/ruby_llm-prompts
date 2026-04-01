Rails.application.routes.draw do
  mount RubyLLM::Prompts::Engine, at: "/prompts"

  get "playground" => "playground#index", as: :playground_index
  get "playground/*slug" => "playground#show", as: :playground_prompt
  post "playground/*slug/run" => "playground#run", as: :playground_run

  root to: "playground#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
