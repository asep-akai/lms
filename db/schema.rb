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

ActiveRecord::Schema[8.1].define(version: 2026_09_14_121000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admins", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
  end

  create_table "audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "actor_id"
    t.string "actor_type"
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.bigint "organization_id"
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_events_on_action"
    t.index ["actor_id"], name: "index_audit_events_on_actor_id"
    t.index ["actor_type", "actor_id"], name: "index_audit_events_on_actor_type_and_actor_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable"
    t.index ["organization_id", "occurred_at"], name: "index_audit_events_on_organization_id_and_occurred_at"
    t.index ["organization_id"], name: "index_audit_events_on_organization_id"
  end

  create_table "course_enrollments", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.bigint "membership_id", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id", "membership_id"], name: "index_course_enrollments_on_course_id_and_membership_id", unique: true
    t.index ["course_id"], name: "index_course_enrollments_on_course_id"
    t.index ["membership_id"], name: "index_course_enrollments_on_membership_id"
  end

  create_table "courses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "name"], name: "index_courses_on_organization_id_and_name"
    t.index ["organization_id"], name: "index_courses_on_organization_id"
  end

  create_table "materials", force: :cascade do |t|
    t.text "body_html", null: false
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_materials_on_course_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["organization_id", "status"], name: "index_memberships_on_organization_id_and_status"
    t.index ["organization_id", "user_id"], name: "index_memberships_on_organization_id_and_user_id", unique: true
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "locale", default: "en", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.string "status", default: "active", null: false
    t.string "timezone", default: "UTC", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
    t.index ["status"], name: "index_organizations_on_status"
  end

  create_table "permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_permissions_on_key", unique: true
  end

  create_table "quiz_answer_options", force: :cascade do |t|
    t.text "content", null: false
    t.boolean "correct", default: false, null: false
    t.datetime "created_at", null: false
    t.bigint "quiz_question_id", null: false
    t.datetime "updated_at", null: false
    t.index ["quiz_question_id"], name: "index_quiz_answer_options_on_quiz_question_id"
  end

  create_table "quiz_answer_overrides", force: :cascade do |t|
    t.boolean "correct", null: false
    t.datetime "created_at", null: false
    t.bigint "quiz_attempt_id", null: false
    t.bigint "quiz_question_id", null: false
    t.datetime "updated_at", null: false
    t.index ["quiz_attempt_id", "quiz_question_id"], name: "idx_on_quiz_attempt_id_quiz_question_id_4bde5e5bfc", unique: true
    t.index ["quiz_attempt_id"], name: "index_quiz_answer_overrides_on_quiz_attempt_id"
    t.index ["quiz_question_id"], name: "index_quiz_answer_overrides_on_quiz_question_id"
  end

  create_table "quiz_answers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "quiz_answer_option_id"
    t.bigint "quiz_attempt_id", null: false
    t.bigint "quiz_question_id", null: false
    t.text "short_answer_response"
    t.datetime "updated_at", null: false
    t.index ["quiz_answer_option_id"], name: "index_quiz_answers_on_quiz_answer_option_id"
    t.index ["quiz_attempt_id", "quiz_question_id"], name: "index_quiz_answers_on_quiz_attempt_id_and_quiz_question_id", unique: true
    t.index ["quiz_attempt_id"], name: "index_quiz_answers_on_quiz_attempt_id"
    t.index ["quiz_question_id"], name: "index_quiz_answers_on_quiz_question_id"
  end

  create_table "quiz_attempts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_activity_at", null: false
    t.integer "last_question_position"
    t.bigint "membership_id", null: false
    t.bigint "quiz_id", null: false
    t.datetime "reviewed_at"
    t.datetime "started_at", null: false
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.index ["membership_id"], name: "index_quiz_attempts_on_membership_id"
    t.index ["quiz_id", "membership_id"], name: "index_quiz_attempts_on_quiz_id_and_membership_id", unique: true
    t.index ["quiz_id"], name: "index_quiz_attempts_on_quiz_id"
  end

  create_table "quiz_questions", force: :cascade do |t|
    t.text "content_html", null: false
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.string "question_type", null: false
    t.bigint "quiz_id", null: false
    t.string "short_answer"
    t.datetime "updated_at", null: false
    t.index ["quiz_id", "position"], name: "index_quiz_questions_on_quiz_id_and_position"
    t.index ["quiz_id"], name: "index_quiz_questions_on_quiz_id"
  end

  create_table "quizzes", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id", "title"], name: "index_quizzes_on_course_id_and_title"
    t.index ["course_id"], name: "index_quizzes_on_course_id"
  end

  create_table "role_assignments", force: :cascade do |t|
    t.bigint "assignee_id", null: false
    t.string "assignee_type", null: false
    t.datetime "created_at", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_type", "assignee_id"], name: "index_role_assignments_on_assignee"
    t.index ["role_id", "assignee_type", "assignee_id"], name: "index_role_assignments_uniqueness", unique: true
    t.index ["role_id"], name: "index_role_assignments_on_role_id"
  end

  create_table "role_permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "permission_id", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_role_permissions_on_permission_id"
    t.index ["role_id", "permission_id"], name: "index_role_permissions_on_role_id_and_permission_id", unique: true
    t.index ["role_id"], name: "index_role_permissions_on_role_id"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.string "name", null: false
    t.bigint "organization_id"
    t.boolean "system", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_global_roles_on_key", unique: true, where: "(organization_id IS NULL)"
    t.index ["organization_id", "key"], name: "index_roles_on_organization_id_and_key", unique: true
    t.index ["organization_id"], name: "index_roles_on_organization_id"
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.integer "completed_jobs", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "enqueued_at"
    t.datetime "failed_at"
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "finished_at"
    t.text "metadata"
    t.text "on_failure"
    t.text "on_finish"
    t.text "on_success"
    t.integer "total_jobs", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.bigint "batch_id"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "encrypted_password", null: false
    t.datetime "invited_at"
    t.string "name", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_events", "organizations"
  add_foreign_key "course_enrollments", "courses"
  add_foreign_key "course_enrollments", "memberships"
  add_foreign_key "courses", "organizations"
  add_foreign_key "materials", "courses"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "quiz_answer_options", "quiz_questions"
  add_foreign_key "quiz_answer_overrides", "quiz_attempts"
  add_foreign_key "quiz_answer_overrides", "quiz_questions"
  add_foreign_key "quiz_answers", "quiz_answer_options"
  add_foreign_key "quiz_answers", "quiz_attempts"
  add_foreign_key "quiz_answers", "quiz_questions"
  add_foreign_key "quiz_attempts", "memberships"
  add_foreign_key "quiz_attempts", "quizzes"
  add_foreign_key "quiz_questions", "quizzes"
  add_foreign_key "quizzes", "courses"
  add_foreign_key "role_assignments", "roles"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "roles", "organizations"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
