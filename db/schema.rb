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

ActiveRecord::Schema[7.2].define(version: 2026_03_30_200202) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "events", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "location", null: false
    t.datetime "start_time", null: false
    t.datetime "end_time", null: false
    t.string "status", default: "upcoming", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["start_time"], name: "index_events_on_start_time"
    t.index ["status"], name: "index_events_on_status"
  end

  create_table "ticket_types", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.integer "quantity", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "name"], name: "index_ticket_types_on_event_id_and_name", unique: true
    t.index ["event_id"], name: "index_ticket_types_on_event_id"
  end

  add_foreign_key "ticket_types", "events"
end
