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

ActiveRecord::Schema[7.2].define(version: 2026_02_20_153000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "rephrases", force: :cascade do |t|
    t.text "content", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_rephrases_on_category_id"
  end

  create_table "search_logs", force: :cascade do |t|
    t.string "query", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "converted_text", null: false
    t.integer "category_id", null: false
    t.integer "hit_type", default: 2, null: false
    t.boolean "safety_mode_applied", default: false, null: false
    t.index ["category_id"], name: "index_search_logs_on_category_id"
    t.index ["hit_type"], name: "index_search_logs_on_hit_type"
  end

  add_foreign_key "rephrases", "categories"
end
