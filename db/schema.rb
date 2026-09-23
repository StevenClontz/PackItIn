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

ActiveRecord::Schema[8.1].define(version: 2026_09_23_232328) do
  create_table "double_entry_account_balances", force: :cascade do |t|
    t.string "account", null: false
    t.bigint "balance", null: false
    t.datetime "created_at", null: false
    t.string "scope"
    t.datetime "updated_at", null: false
    t.index ["account"], name: "index_account_balances_on_account"
    t.index ["scope", "account"], name: "index_account_balances_on_scope_and_account", unique: true
  end

  create_table "double_entry_line_checks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "errors_found", null: false
    t.integer "last_line_id", null: false
    t.text "log"
    t.datetime "updated_at", null: false
    t.index ["created_at", "last_line_id"], name: "line_checks_created_at_last_line_id_idx"
  end

  create_table "double_entry_lines", force: :cascade do |t|
    t.string "account", null: false
    t.bigint "amount", null: false
    t.bigint "balance", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.integer "detail_id"
    t.string "detail_type"
    t.json "metadata"
    t.string "partner_account", null: false
    t.integer "partner_id"
    t.string "partner_scope"
    t.string "scope"
    t.datetime "updated_at", null: false
    t.index ["account", "code", "created_at"], name: "lines_account_code_created_at_idx"
    t.index ["account", "created_at"], name: "lines_account_created_at_idx"
    t.index ["scope", "account", "created_at"], name: "lines_scope_account_created_at_idx"
    t.index ["scope", "account", "id"], name: "lines_scope_account_id_idx"
  end

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
    t.boolean "password_only", default: false, null: false
    t.datetime "remember_created_at"
    t.integer "state", null: false
    t.string "street_address", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.string "zip", null: false
    t.index ["username"], name: "index_families_on_username", unique: true
  end

  create_table "funds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_funds_on_name", unique: true
  end

  create_table "people", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "den", null: false
    t.string "email"
    t.integer "family_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "phone_number"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_people_on_email", unique: true
    t.index ["family_id"], name: "index_people_on_family_id"
    t.index ["phone_number"], name: "index_people_on_phone_number", unique: true
  end

  create_table "rsvp_options", force: :cascade do |t|
    t.bigint "cost_cents"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "event_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "youth_cost_cents"
    t.index ["event_id", "name"], name: "index_rsvp_options_on_event_id_and_name", unique: true
    t.index ["event_id"], name: "index_rsvp_options_on_event_id"
  end

  create_table "rsvps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "event_id", null: false
    t.integer "person_id", null: false
    t.integer "rsvp_option_id"
    t.integer "status", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "person_id"], name: "index_rsvps_on_event_id_and_person_id", unique: true
    t.index ["event_id"], name: "index_rsvps_on_event_id"
    t.index ["person_id"], name: "index_rsvps_on_person_id"
    t.index ["rsvp_option_id"], name: "index_rsvps_on_rsvp_option_id"
  end

  add_foreign_key "people", "families"
  add_foreign_key "rsvp_options", "events"
  add_foreign_key "rsvps", "events"
  add_foreign_key "rsvps", "people"
  add_foreign_key "rsvps", "rsvp_options", on_delete: :nullify
end
