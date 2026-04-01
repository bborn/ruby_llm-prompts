# frozen_string_literal: true

module RubyLLM
  module Prompts
    module AgentIntegration
      # Prepended onto RubyLLM::Agent's singleton class.
      # Intercepts render_prompt to check the database first.
      # If a matching prompt exists in the DB, renders it with Liquid.
      # Otherwise, falls back to the original ERB file-based rendering.
      def render_prompt(name, chat:, inputs:, locals:)
        slug = prompt_slug_for(name)
        db_prompt = Prompt.active.find_by(slug: slug)

        if db_prompt
          resolved = resolve_prompt_locals(locals, runtime: runtime_context(chat:, inputs:), chat:, inputs:)
          db_prompt.render(resolved)
        else
          super
        end
      end

      private

      # Convert agent class + prompt name to a database slug.
      # WorkAssistant + "instructions" => "work_assistant/instructions"
      # Admin::SupportAgent + "greeting" => "admin/support_agent/greeting"
      def prompt_slug_for(name)
        "#{prompt_agent_path}/#{name}"
      end
    end
  end
end
