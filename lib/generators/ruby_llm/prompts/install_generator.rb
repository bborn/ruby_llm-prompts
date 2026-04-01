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

        def create_prompts_directory
          empty_directory "db/prompts"
          create_file "db/prompts/.keep"
        end

        def create_seed_example
          template "example_prompt.yml", "db/prompts/example/instructions.yml"
        end

        def add_seed_line
          append_to_file "db/seeds.rb", <<~RUBY

            # Seed RubyLLM prompts from db/prompts/
            RubyLLM::Prompts.seed!
          RUBY
        end

        def display_post_install
          say ""
          say "RubyLLM::Prompts installed!", :green
          say ""
          say "  1. Run migrations:    rails db:migrate"
          say "  2. Mount the admin:   mount RubyLLM::Prompts::Engine, at: \"/prompts\""
          say "  3. Add prompts to:    db/prompts/"
          say "  4. Seed them:         rails db:seed"
          say ""
        end
      end
    end
  end
end
