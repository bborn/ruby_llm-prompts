# frozen_string_literal: true

require_relative "lib/ruby_llm/prompts/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_llm-prompts"
  spec.version = RubyLLM::Prompts::VERSION
  spec.summary = "Database-backed prompt management for RubyLLM"
  spec.homepage = "https://github.com/codenamev/ruby_llm-prompts"
  spec.license = "MIT"

  spec.author = "Bruno Bornsztein"
  spec.email = "bruno@codenamev.com"

  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["*.{md,txt}", "{app,config,db,lib}/**/*"]

  spec.add_dependency "activerecord", ">= 7.0"
  spec.add_dependency "liquid2", ">= 0.1"
  spec.add_dependency "ruby_llm", ">= 1.0"
  spec.add_dependency "zeitwerk", ">= 2.0"
end
