# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RubyLLM
  module Prompts
    module Generators
      class InstallGenerator < Rails::Generators::Base
        include ActiveRecord::Generators::Migration

        source_root File.expand_path("templates", __dir__)

        def copy_migration
          migration_template "migration.rb", "db/migrate/create_ruby_llm_prompts.rb"
        end

        def display_post_install
          say ""
          say "RubyLLM::Prompts installed!", :green
          say ""
          say "  1. Run migrations:    rails db:migrate"
          say "  2. Mount the admin:   mount RubyLLM::Prompts::Engine, at: \"/prompts\""
          say ""
        end
      end
    end
  end
end
