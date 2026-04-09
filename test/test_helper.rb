require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"

require "ruby_llm-prompts"

ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

ActiveRecord::Schema.define do
  create_table :ruby_llm_prompts, force: true do |t|
    t.string :slug, null: false
    t.text :body, null: false
    t.text :system_message
    t.integer :version, null: false, default: 1
    t.boolean :active, null: false, default: true
    t.json :metadata

    t.timestamps

    t.index [:slug, :version], unique: true
    t.index [:slug, :active]
  end
end

class Minitest::Test
  def setup
    RubyLLM::Prompts::Prompt.delete_all
    RubyLLM::Prompts.strict_variables = true
    RubyLLM::Prompts.prompts_path = nil
  end
end
