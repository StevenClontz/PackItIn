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

ActiveRecord::Schema[8.1].define(version: 2026_09_20_032028) do
  create_table "events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "ends_at", null: false
    t.datetime "rsvp_deadline_at"
    t.datetime "starts_at", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["starts_at"], name: "index_events_on_starts_at"
  end

  create_table "families", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.string "city", null: false
    t.datetime "created_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", null: false
    t.datetime "remember_created_at"
    t.integer "state", null: false
    t.string "street_address", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.string "zip", null: false
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

  create_table "rsvps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "event_id", null: false
    t.integer "person_id", null: false
    t.integer "status", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "person_id"], name: "index_rsvps_on_event_id_and_person_id", unique: true
    t.index ["event_id"], name: "index_rsvps_on_event_id"
    t.index ["person_id"], name: "index_rsvps_on_person_id"
  end

  add_foreign_key "people", "families"
  add_foreign_key "rsvps", "events"
  add_foreign_key "rsvps", "people"
end
