# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_01_000001) do
  create_table "ruby_llm_prompts", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.json "metadata"
    t.string "slug", null: false
    t.text "system_message"
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.index ["slug", "active"], name: "index_ruby_llm_prompts_on_slug_and_active"
    t.index ["slug", "version"], name: "index_ruby_llm_prompts_on_slug_and_version", unique: true
  end
end
