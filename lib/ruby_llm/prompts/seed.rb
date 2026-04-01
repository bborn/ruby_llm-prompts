# frozen_string_literal: true

require "yaml"

module RubyLLM
  module Prompts
    module Seed
      def self.call(path:)
        dir = path.is_a?(Pathname) ? path : Pathname.new(path)
        dir = Rails.root.join(dir) if defined?(Rails) && dir.relative?

        raise Error, "Prompts directory not found: #{dir}" unless dir.exist?

        count = 0
        Dir[dir.join("**/*.yml")].each do |file|
          data = YAML.safe_load(File.read(file), permitted_classes: [Symbol])
          slug = data.fetch("slug")
          body = data.fetch("body")
          metadata = data["metadata"]

          existing = Prompt.active.find_by(slug: slug)

          if existing.nil?
            Prompt.create!(slug: slug, body: body, metadata: metadata, version: 1, active: true)
            count += 1
          elsif existing.body != body || existing.metadata != metadata
            existing.new_version!(body: body, metadata: metadata)
            count += 1
          end
        end
        count
      end
    end
  end
end
