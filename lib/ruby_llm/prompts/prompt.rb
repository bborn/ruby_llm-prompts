# frozen_string_literal: true

module RubyLLM
  module Prompts
    class Prompt < ::ActiveRecord::Base
      self.table_name = "ruby_llm_prompts"

      validates :slug, presence: true
      validates :body, presence: true
      validates :version, presence: true, uniqueness: {scope: :slug}

      scope :active, -> { where(active: true) }

      def render(variables = {})
        template = Liquid::Template.parse(body)
        coerced = coerce_variables(variables)
        result = if RubyLLM::Prompts.strict_variables
          template.render!(coerced, strict_variables: true)
        else
          template.render(coerced)
        end

        ActiveSupport::Notifications.instrument("render_prompt.ruby_llm_prompts",
          slug: slug, version: version, metadata: metadata)

        result
      rescue Liquid::UndefinedVariable => e
        raise UndefinedVariableError, "#{e.message} in prompt '#{slug}' (v#{version}). Expected variables: #{expected_variables.join(", ")}"
      end

      def expected_variables
        # {{ variable }} references
        output_vars = body.scan(/\{\{[\s-]*(\w+)/).flatten

        # {% if var %}, {% unless var %}, {% for var in collection %} — extract variable names after keywords
        tag_vars = body.scan(/\{%[\s-]*(?:if|unless|elsif|for)\s+(\w+)/).flatten

        (output_vars + tag_vars).uniq
      end

      def new_version!(attrs = {})
        self.class.transaction do
          self.class.where(slug: slug).update_all(active: false)
          self.class.create!(
            slug: slug,
            body: attrs[:body] || body,
            metadata: attrs[:metadata] || metadata,
            version: (self.class.where(slug: slug).maximum(:version) || 0) + 1,
            active: true
          )
        end
      end

      def rollback!
        previous = self.class.where(slug: slug)
          .where("version < ?", version)
          .order(version: :desc)
          .first

        raise Error, "No previous version to roll back to" unless previous

        self.class.transaction do
          self.class.where(slug: slug).update_all(active: false)
          previous.update!(active: true)
        end

        previous
      end

      private

      # Coerce variable values for Liquid compatibility.
      # - Stringify keys (Liquid requires string keys)
      # - Convert "true"/"false" strings to booleans
      # - Convert empty strings to nil (so {% if var %} works intuitively)
      def coerce_variables(variables)
        variables.each_with_object({}) do |(key, value), hash|
          hash[key.to_s] = coerce_value(value)
        end
      end

      def coerce_value(value)
        case value
        when "" then nil
        when "true" then true
        when "false" then false
        else value
        end
      end
    end
  end
end
