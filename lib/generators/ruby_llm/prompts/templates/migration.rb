class CreateRubyLLMPrompts < ActiveRecord::Migration[7.0]
  def change
    create_table :ruby_llm_prompts do |t|
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
end
