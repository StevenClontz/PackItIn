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

ActiveRecord::Schema[8.1].define(version: 2026_09_19_033030) do
  create_table "families", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["username"], name: "index_families_on_username", unique: true
  end

  create_table "people", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "family_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_people_on_family_id"
  end

  add_foreign_key "people", "families"
end
