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

ActiveRecord::Schema[8.1].define(version: 2026_10_15_232208) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "contest_participations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "contest_id", null: false
    t.integer "solved_count", default: 0, null: false
    t.integer "penalty", default: 0, null: false
    t.integer "rank"
    t.datetime "registered_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contest_id", "solved_count", "penalty"], name: "index_contest_participations_on_standings"
    t.index ["contest_id"], name: "index_contest_participations_on_contest_id"
    t.index ["user_id", "contest_id"], name: "index_contest_participations_on_user_id_and_contest_id", unique: true
    t.index ["user_id"], name: "index_contest_participations_on_user_id"
  end

  create_table "contest_problems", force: :cascade do |t|
    t.bigint "contest_id", null: false
    t.bigint "problem_id", null: false
    t.integer "position", null: false
    t.string "letter", limit: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contest_id", "letter"], name: "index_contest_problems_on_contest_id_and_letter", unique: true
    t.index ["contest_id", "position"], name: "index_contest_problems_on_contest_id_and_position", unique: true
    t.index ["contest_id", "problem_id"], name: "index_contest_problems_on_contest_id_and_problem_id", unique: true
    t.index ["contest_id"], name: "index_contest_problems_on_contest_id"
    t.index ["problem_id"], name: "index_contest_problems_on_problem_id"
  end

  create_table "contests", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "status", default: "upcoming", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["starts_at"], name: "index_contests_on_starts_at"
    t.index ["status"], name: "index_contests_on_status"
  end

  create_table "problems", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug", null: false
    t.text "statement", null: false
    t.integer "time_limit_ms", default: 1000, null: false
    t.integer "memory_limit_mb", default: 256, null: false
    t.integer "rating", null: false
    t.string "tags", default: [], null: false, array: true
    t.text "sample_input"
    t.text "sample_output"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["rating"], name: "index_problems_on_rating"
    t.index ["slug"], name: "index_problems_on_slug", unique: true
  end

  create_table "rating_histories", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "contest_id", null: false
    t.integer "old_rating", null: false
    t.integer "new_rating", null: false
    t.integer "rank"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contest_id"], name: "index_rating_histories_on_contest_id"
    t.index ["user_id", "contest_id"], name: "index_rating_histories_on_user_id_and_contest_id", unique: true
    t.index ["user_id", "created_at"], name: "index_rating_histories_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_rating_histories_on_user_id"
  end

  create_table "submissions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "problem_id", null: false
    t.bigint "contest_id"
    t.string "language", null: false
    t.text "source_code", null: false
    t.string "status", default: "queued", null: false
    t.integer "time_ms"
    t.integer "memory_kb"
    t.string "judge0_token"
    t.text "stdout"
    t.text "stderr"
    t.text "compile_output"
    t.datetime "submitted_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contest_id", "user_id", "problem_id"], name: "index_submissions_on_contest_id_and_user_id_and_problem_id"
    t.index ["contest_id"], name: "index_submissions_on_contest_id"
    t.index ["judge0_token"], name: "index_submissions_on_judge0_token", unique: true
    t.index ["problem_id"], name: "index_submissions_on_problem_id"
    t.index ["status"], name: "index_submissions_on_status"
    t.index ["user_id", "created_at"], name: "index_submissions_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_submissions_on_user_id"
  end

  create_table "test_cases", force: :cascade do |t|
    t.bigint "problem_id", null: false
    t.integer "position", null: false
    t.boolean "sample", default: false, null: false
    t.text "stdin"
    t.text "expected_output"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["problem_id", "position"], name: "index_test_cases_on_problem_id_and_position", unique: true
    t.index ["problem_id"], name: "index_test_cases_on_problem_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.integer "rating", default: 1500, null: false
    t.integer "max_rating", default: 1500, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "contest_participations", "contests"
  add_foreign_key "contest_participations", "users"
  add_foreign_key "contest_problems", "contests"
  add_foreign_key "contest_problems", "problems"
  add_foreign_key "rating_histories", "contests"
  add_foreign_key "rating_histories", "users"
  add_foreign_key "submissions", "contests"
  add_foreign_key "submissions", "problems"
  add_foreign_key "submissions", "users"
  add_foreign_key "test_cases", "problems"
end
