# frozen_string_literal: true

require "active_record"
require "liquid2"
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
      attr_accessor :strict_variables

      def get(slug)
        Prompt.active.find_by!(slug: slug)
      rescue ::ActiveRecord::RecordNotFound
        raise PromptNotFoundError, "No active prompt found for slug: #{slug}"
      end

      def render(slug, variables = {})
        get(slug).render(variables)
      end

      def variables(slug)
        get(slug).variables
      end

      # Liquid2 environments — strict mode is per-environment, not per-render.
      def strict_environment
        @strict_environment ||= Liquid2::Environment.new(undefined: Liquid2::StrictUndefined)
      end

      def lax_environment
        @lax_environment ||= Liquid2::Environment.new
      end

      def environment
        strict_variables ? strict_environment : lax_environment
      end
    end

    self.strict_variables = true
  end
end

require_relative "prompts/engine" if defined?(Rails::Engine)
