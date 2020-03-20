# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_03_13_201156) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "event_records", force: :cascade do |t|
    t.string "event_type", null: false
    t.jsonb "data", default: {}, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "event_stream_ids", id: :bigint, default: nil, force: :cascade do |t|
  end

  create_table "event_streams", id: :bigint, default: nil, force: :cascade do |t|
    t.bigint "event_record_id", null: false
    t.index ["event_record_id"], name: "index_event_streams_on_event_record_id", unique: true
    t.index ["id"], name: "index_event_streams_on_id", unique: true
  end

  create_table "events_queue", id: false, force: :cascade do |t|
    t.bigint "event_record_id", null: false
    t.index ["event_record_id"], name: "index_events_queue_on_event_record_id", unique: true
  end

  create_table "stream_events", id: false, force: :cascade do |t|
    t.uuid "event_id", null: false
    t.integer "stream_id", null: false
    t.integer "stream_version", null: false
  end

  create_table "streams", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.integer "version", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

end
