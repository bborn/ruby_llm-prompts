# frozen_string_literal: true

module RubyLLM
  module Prompts
    class Engine < ::Rails::Engine
      isolate_namespace RubyLLM::Prompts

      initializer "ruby_llm_prompts.inflections" do
        ActiveSupport::Inflector.inflections do |inflect|
          inflect.acronym "LLM"
        end

        Rails.autoloaders.each do |loader|
          loader.inflector.inflect("ruby_llm" => "RubyLLM")
        end
      end

      # Hook into RubyLLM::Agent if the gem is loaded.
      # Prepends AgentIntegration so render_prompt checks the DB first.
      initializer "ruby_llm_prompts.agent_integration" do
        ActiveSupport.on_load(:active_record) do
          if defined?(RubyLLM::Agent)
            require_relative "agent_integration"
            RubyLLM::Agent.singleton_class.prepend(RubyLLM::Prompts::AgentIntegration)
          end
        end
      end
    end
  end
end
