# frozen_string_literal: true

require "active_record"
require "erb"
require "liquid"
require "ruby_llm"
require "zeitwerk"

loader = Zeitwerk::Loader.for_gem_extension(RubyLLM)
loader.inflector.inflect("llm" => "LLM")
loader.setup

module RubyLLM
  module Prompts
    class Error < StandardError; end
    class PromptNotFoundError < Error; end
    class UndefinedVariableError < Error; end

    class << self
      attr_accessor :strict_variables, :prompts_path

      def get(slug)
        Prompt.active.find_by!(slug: slug)
      rescue ::ActiveRecord::RecordNotFound
        raise PromptNotFoundError, "No active prompt found for slug: #{slug}"
      end

      # Render a prompt by slug. Checks DB first (Liquid), then falls back
      # to filesystem ERB templates matching RubyLLM conventions.
      def render(slug, variables = {})
        prompt = Prompt.active.find_by(slug: slug)
        return prompt.render(variables) if prompt

        render_from_filesystem(slug, variables)
      end

      def variables(slug)
        get(slug).variables
      end

      def resolved_prompts_path
        path = prompts_path
        if path.nil? && defined?(Rails)
          path = Rails.root.join("app", "prompts")
        end
        path&.is_a?(Pathname) ? path : (path && Pathname.new(path))
      end

      private

      def render_from_filesystem(slug, variables)
        dir = resolved_prompts_path
        raise PromptNotFoundError, "No prompts_path configured and not in a Rails app" unless dir

        file = dir.join("#{slug}.txt.erb")
        raise PromptNotFoundError, "No prompt found for slug: #{slug} (checked DB and #{file})" unless file.exist?

        erb = ERB.new(file.read, trim_mode: "-")
        context = ErbContext.new(**variables)
        rendered = erb.result(context._binding).strip

        Result.new(
          body: rendered,
          slug: slug,
          version: nil,
          metadata: nil
        )
      end
    end

    self.strict_variables = true
    self.prompts_path = nil

    # Clean binding context for ERB — variables become methods.
    class ErbContext
      def initialize(**locals)
        locals.each do |key, value|
          define_singleton_method(key) { value }
        end
      end

      def _binding
        binding
      end
    end
  end
end

require_relative "prompts/engine" if defined?(Rails::Engine)
