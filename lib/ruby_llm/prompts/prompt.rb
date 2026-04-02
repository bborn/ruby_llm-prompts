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
        coerced = coerce_variables(variables)
        rendered_body = render_template(body, coerced)
        rendered_system = render_template(system_message, coerced) if system_message.present?

        ActiveSupport::Notifications.instrument("render_prompt.ruby_llm_prompts",
          slug: slug, version: version, metadata: metadata)

        Result.new(
          body: rendered_body,
          system_message: rendered_system,
          slug: slug,
          version: version,
          metadata: metadata
        )
      end

      def variables
        sources = [body, system_message].compact
        sources.flat_map { |src|
          env = RubyLLM::Prompts.environment
          env.parse(src).global_variables
        }.uniq
      end

      def new_version!(attrs = {})
        self.class.transaction do
          self.class.where(slug: slug).update_all(active: false)
          self.class.create!(
            slug: slug,
            body: attrs[:body] || body,
            system_message: attrs.key?(:system_message) ? attrs[:system_message] : system_message,
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

      def render_template(template_string, coerced_variables)
        return nil if template_string.blank?

        env = RubyLLM::Prompts.environment
        template = env.parse(template_string)
        template.render(coerced_variables)
      rescue Liquid2::UndefinedError => e
        raise UndefinedVariableError, "#{e.message} in prompt '#{slug}' (v#{version}). Expected variables: #{variables.join(", ")}"
      end

      # Coerce variable values for Liquid compatibility.
      # - Stringify keys (Liquid2 requires string keys)
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
