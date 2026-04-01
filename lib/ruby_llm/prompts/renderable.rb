# frozen_string_literal: true

module RubyLLM
  module Prompts
    # Mixin for custom agent classes that aren't RubyLLM::Agent subclasses.
    # Provides a render_prompt that checks the DB first, then falls back
    # to the filesystem ERB rendering.
    #
    #   class ApplicationAgent
    #     include RubyLLM::Prompts::Renderable
    #
    #     def chat(prompt_name = :instructions)
    #       prompt = render_prompt(prompt_name)
    #       RubyLLM.chat.ask(prompt)
    #     end
    #   end
    #
    module Renderable
      def render_prompt(prompt_name, **variables)
        slug = "#{agent_name}/#{prompt_name}"
        db_prompt = Prompt.active.find_by(slug: slug)

        if db_prompt
          db_prompt.render(variables.merge(context_variables))
        elsif respond_to?(:render_erb_prompt, true)
          render_erb_prompt(prompt_name)
        else
          path = prompt_path(prompt_name)
          raise PromptNotFoundError, "No prompt found for '#{slug}' in database or at #{path}" unless File.exist?(path)
          ERB.new(File.read(path)).result(binding)
        end
      end

      private

      def agent_name
        self.class.name.underscore
      end

      def prompt_path(prompt_name)
        root = defined?(Rails) ? Rails.root.join("app/prompts") : Pathname.new(Dir.pwd).join("app/prompts")
        root.join(agent_name, "#{prompt_name}.txt.erb")
      end

      # Override this in your agent to provide variables for Liquid rendering.
      # Instance variables are automatically available in ERB via binding,
      # but Liquid needs explicit variables.
      def context_variables
        {}
      end
    end
  end
end
