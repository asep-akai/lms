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

ActiveRecord::Schema[8.1].define(version: 2026_09_24_100000) do
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

  create_table "assignment_recipients", force: :cascade do |t|
    t.bigint "assignment_id", null: false
    t.datetime "created_at", null: false
    t.bigint "student_membership_id", null: false
    t.datetime "updated_at", null: false
    t.index ["assignment_id", "student_membership_id"], name: "idx_on_assignment_id_student_membership_id_fa7710ba70", unique: true
    t.index ["assignment_id"], name: "index_assignment_recipients_on_assignment_id"
    t.index ["student_membership_id"], name: "index_assignment_recipients_on_student_membership_id"
  end

  create_table "assignment_submissions", force: :cascade do |t|
    t.bigint "assignment_recipient_id", null: false
    t.text "body"
    t.datetime "commented_at"
    t.datetime "created_at", null: false
    t.datetime "submitted_at"
    t.text "teacher_comment"
    t.datetime "updated_at", null: false
    t.index ["assignment_recipient_id"], name: "index_assignment_submissions_on_assignment_recipient_id", unique: true
  end

  create_table "assignments", force: :cascade do |t|
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "deadline", null: false
    t.text "description", null: false
    t.bigint "organization_id", null: false
    t.bigint "teacher_membership_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["cancelled_at"], name: "index_assignments_on_cancelled_at"
    t.index ["organization_id"], name: "index_assignments_on_organization_id"
    t.index ["teacher_membership_id"], name: "index_assignments_on_teacher_membership_id"
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

  create_table "certificates", force: :cascade do |t|
    t.string "certificate_type", null: false
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.datetime "generated_at", null: false
    t.bigint "issued_by_membership_id"
    t.bigint "organization_id", null: false
    t.bigint "recipient_membership_id", null: false
    t.bigint "source_id", null: false
    t.string "source_type", null: false
    t.datetime "unpublished_at"
    t.bigint "unpublished_by_membership_id"
    t.datetime "updated_at", null: false
    t.index ["issued_by_membership_id"], name: "index_certificates_on_issued_by_membership_id"
    t.index ["organization_id"], name: "index_certificates_on_organization_id"
    t.index ["recipient_membership_id"], name: "index_certificates_on_recipient_membership_id"
    t.index ["source_type", "source_id", "recipient_membership_id", "certificate_type"], name: "index_certificates_on_published_source_and_recipient", unique: true, where: "(unpublished_at IS NULL)"
    t.index ["source_type", "source_id"], name: "index_certificates_on_source"
    t.index ["unpublished_at"], name: "index_certificates_on_unpublished_at"
    t.index ["unpublished_by_membership_id"], name: "index_certificates_on_unpublished_by_membership_id"
  end

  create_table "class_meeting_feedbacks", force: :cascade do |t|
    t.bigint "author_membership_id", null: false
    t.string "author_role", null: false
    t.bigint "class_meeting_id", null: false
    t.text "comment"
    t.datetime "created_at", null: false
    t.text "feedback_to_student"
    t.text "internal_feedback"
    t.text "next_topics"
    t.integer "rating", null: false
    t.text "topics_discussed"
    t.datetime "updated_at", null: false
    t.index ["author_membership_id"], name: "index_class_meeting_feedbacks_on_author_membership_id"
    t.index ["class_meeting_id", "author_membership_id"], name: "index_class_feedbacks_on_meeting_and_author", unique: true
    t.index ["class_meeting_id"], name: "index_class_meeting_feedbacks_on_class_meeting_id"
    t.check_constraint "author_role::text = ANY (ARRAY['teacher'::character varying, 'student'::character varying]::text[])", name: "class_meeting_feedbacks_author_role"
    t.check_constraint "rating >= 1 AND rating <= 5", name: "class_meeting_feedbacks_rating_range"
  end

  create_table "class_meeting_students", force: :cascade do |t|
    t.bigint "class_meeting_id", null: false
    t.datetime "created_at", null: false
    t.bigint "membership_id", null: false
    t.datetime "updated_at", null: false
    t.index ["class_meeting_id", "membership_id"], name: "index_class_meeting_students_on_meeting_and_membership", unique: true
    t.index ["class_meeting_id"], name: "index_class_meeting_students_on_class_meeting_id"
    t.index ["membership_id"], name: "index_class_meeting_students_on_membership_id"
  end

  create_table "class_meetings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "delivery_mode", null: false
    t.integer "meeting_number", null: false
    t.string "meeting_url"
    t.bigint "organization_id", null: false
    t.datetime "starts_at", null: false
    t.string "subject", null: false
    t.string "subject_key", null: false
    t.bigint "teacher_membership_id", null: false
    t.string "topic", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "subject_key", "meeting_number"], name: "index_class_meetings_on_subject_sequence", unique: true
    t.index ["organization_id"], name: "index_class_meetings_on_organization_id"
    t.index ["teacher_membership_id"], name: "index_class_meetings_on_teacher_membership_id"
  end

  create_table "course_contents", force: :cascade do |t|
    t.bigint "contentable_id", null: false
    t.string "contentable_type", null: false
    t.bigint "course_id", null: false
    t.bigint "course_section_id", null: false
    t.datetime "created_at", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["contentable_type", "contentable_id"], name: "index_course_contents_on_contentable"
    t.index ["contentable_type", "contentable_id"], name: "index_course_contents_on_contentable_type_and_contentable_id", unique: true
    t.index ["course_id"], name: "index_course_contents_on_course_id"
    t.index ["course_section_id", "position"], name: "index_course_contents_on_course_section_id_and_position", unique: true
    t.index ["course_section_id"], name: "index_course_contents_on_course_section_id"
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

  create_table "course_sections", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id", "position"], name: "index_course_sections_on_course_id_and_position", unique: true
    t.index ["course_id"], name: "index_course_sections_on_course_id"
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

  create_table "material_blocks", force: :cascade do |t|
    t.string "block_type", null: false
    t.text "body_html"
    t.datetime "created_at", null: false
    t.bigint "material_id", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.string "video_url"
    t.index ["material_id", "position"], name: "index_material_blocks_on_material_id_and_position"
    t.index ["material_id"], name: "index_material_blocks_on_material_id"
  end

  create_table "material_completions", force: :cascade do |t|
    t.datetime "completed_at", null: false
    t.datetime "created_at", null: false
    t.bigint "material_id", null: false
    t.bigint "membership_id", null: false
    t.datetime "updated_at", null: false
    t.index ["material_id", "membership_id"], name: "index_material_completions_on_material_id_and_membership_id", unique: true
    t.index ["material_id"], name: "index_material_completions_on_material_id"
    t.index ["membership_id"], name: "index_material_completions_on_membership_id"
  end

  create_table "materials", force: :cascade do |t|
    t.text "body_html"
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
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
    t.string "timezone", default: "Jakarta", null: false
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

  create_table "quiz_answer_ai_grades", force: :cascade do |t|
    t.boolean "correct", null: false
    t.datetime "created_at", null: false
    t.string "model", null: false
    t.bigint "quiz_attempt_id", null: false
    t.bigint "quiz_question_id", null: false
    t.text "rationale", null: false
    t.datetime "updated_at", null: false
    t.index ["quiz_attempt_id", "quiz_question_id"], name: "index_quiz_answer_ai_grades_on_attempt_and_question", unique: true
    t.index ["quiz_attempt_id"], name: "index_quiz_answer_ai_grades_on_quiz_attempt_id"
    t.index ["quiz_question_id"], name: "index_quiz_answer_ai_grades_on_quiz_question_id"
  end

  create_table "quiz_answer_ai_transcriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "model", null: false
    t.bigint "quiz_attempt_id", null: false
    t.bigint "quiz_question_id", null: false
    t.text "transcript", null: false
    t.datetime "updated_at", null: false
    t.index ["quiz_attempt_id", "quiz_question_id"], name: "index_quiz_answer_ai_transcriptions_on_attempt_and_question", unique: true
    t.index ["quiz_attempt_id"], name: "index_quiz_answer_ai_transcriptions_on_quiz_attempt_id"
    t.index ["quiz_question_id"], name: "index_quiz_answer_ai_transcriptions_on_quiz_question_id"
  end

  create_table "quiz_answer_feedbacks", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.string "model"
    t.string "origin", null: false
    t.bigint "quiz_attempt_id", null: false
    t.bigint "quiz_question_id", null: false
    t.datetime "updated_at", null: false
    t.index ["quiz_attempt_id", "quiz_question_id"], name: "index_quiz_answer_feedbacks_on_attempt_and_question", unique: true
    t.index ["quiz_attempt_id"], name: "index_quiz_answer_feedbacks_on_quiz_attempt_id"
    t.index ["quiz_question_id"], name: "index_quiz_answer_feedbacks_on_quiz_question_id"
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

  create_table "quiz_answer_selections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "quiz_answer_id", null: false
    t.bigint "quiz_answer_option_id", null: false
    t.datetime "updated_at", null: false
    t.index ["quiz_answer_id", "quiz_answer_option_id"], name: "index_quiz_answer_selections_on_answer_and_option", unique: true
    t.index ["quiz_answer_id"], name: "index_quiz_answer_selections_on_quiz_answer_id"
    t.index ["quiz_answer_option_id"], name: "index_quiz_answer_selections_on_quiz_answer_option_id"
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
    t.datetime "ai_analysis_generated_at"
    t.string "ai_model"
    t.string "ai_response_id"
    t.integer "attempt_number", default: 1, null: false
    t.datetime "cancelled_at"
    t.string "cancelled_reason"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "grading_mode"
    t.datetime "last_activity_at", null: false
    t.integer "last_question_position"
    t.bigint "membership_id", null: false
    t.text "performance_analysis"
    t.bigint "quiz_id", null: false
    t.text "recommendations"
    t.datetime "reviewed_at"
    t.datetime "started_at", null: false
    t.text "strengths"
    t.datetime "submitted_at"
    t.bigint "superseded_by_attempt_id"
    t.datetime "timed_out_at"
    t.datetime "updated_at", null: false
    t.text "weaknesses"
    t.index ["ai_analysis_generated_at"], name: "index_quiz_attempts_on_ai_analysis_generated_at"
    t.index ["cancelled_at"], name: "index_quiz_attempts_on_cancelled_at"
    t.index ["expires_at"], name: "index_quiz_attempts_on_expires_at"
    t.index ["membership_id"], name: "index_quiz_attempts_on_membership_id"
    t.index ["quiz_id", "membership_id", "attempt_number"], name: "index_quiz_attempts_on_quiz_membership_and_number", unique: true
    t.index ["quiz_id", "membership_id"], name: "index_quiz_attempts_on_active_quiz_and_membership", unique: true, where: "(cancelled_at IS NULL)"
    t.index ["quiz_id"], name: "index_quiz_attempts_on_quiz_id"
    t.index ["superseded_by_attempt_id"], name: "index_quiz_attempts_on_superseded_by_attempt_id"
  end

  create_table "quiz_cloze_responses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position", null: false
    t.bigint "quiz_answer_id", null: false
    t.text "response_text", null: false
    t.datetime "updated_at", null: false
    t.index ["quiz_answer_id", "position"], name: "index_quiz_cloze_responses_on_quiz_answer_id_and_position", unique: true
    t.index ["quiz_answer_id"], name: "index_quiz_cloze_responses_on_quiz_answer_id"
  end

  create_table "quiz_page_blocks", force: :cascade do |t|
    t.string "block_type", null: false
    t.text "body_html"
    t.datetime "created_at", null: false
    t.integer "position", null: false
    t.bigint "quiz_page_id", null: false
    t.datetime "updated_at", null: false
    t.index ["quiz_page_id", "position"], name: "index_quiz_page_blocks_on_quiz_page_id_and_position"
    t.index ["quiz_page_id"], name: "index_quiz_page_blocks_on_quiz_page_id"
  end

  create_table "quiz_pages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "instructions_html"
    t.integer "position", default: 1, null: false
    t.bigint "quiz_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["quiz_id", "position"], name: "index_quiz_pages_on_quiz_id_and_position", unique: true
    t.index ["quiz_id"], name: "index_quiz_pages_on_quiz_id"
  end

  create_table "quiz_questions", force: :cascade do |t|
    t.text "cloze_template"
    t.text "content_html", null: false
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.string "question_type", null: false
    t.bigint "quiz_id", null: false
    t.bigint "quiz_page_id", null: false
    t.string "scoring_mode"
    t.string "short_answer"
    t.datetime "updated_at", null: false
    t.index ["quiz_id", "position"], name: "index_quiz_questions_on_quiz_id_and_position"
    t.index ["quiz_id"], name: "index_quiz_questions_on_quiz_id"
    t.index ["quiz_page_id", "position"], name: "index_quiz_questions_on_quiz_page_id_and_position"
    t.index ["quiz_page_id"], name: "index_quiz_questions_on_quiz_page_id"
  end

  create_table "quizzes", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "retake_limit"
    t.integer "time_limit_minutes"
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

  create_table "support_messages", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.string "author_type", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "support_ticket_id", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_support_messages_on_author"
    t.index ["support_ticket_id"], name: "index_support_messages_on_support_ticket_id"
  end

  create_table "support_tickets", force: :cascade do |t|
    t.string "category", default: "technical_issue", null: false
    t.datetime "created_at", null: false
    t.datetime "escalated_at"
    t.bigint "escalated_by_membership_id"
    t.bigint "organization_id", null: false
    t.string "priority", default: "normal", null: false
    t.bigint "reporter_membership_id", null: false
    t.string "status", default: "open", null: false
    t.string "subject", null: false
    t.datetime "updated_at", null: false
    t.index ["escalated_at"], name: "index_support_tickets_on_escalated_at"
    t.index ["escalated_by_membership_id"], name: "index_support_tickets_on_escalated_by_membership_id"
    t.index ["organization_id", "status"], name: "index_support_tickets_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_support_tickets_on_organization_id"
    t.index ["reporter_membership_id"], name: "index_support_tickets_on_reporter_membership_id"
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
  add_foreign_key "assignment_recipients", "assignments"
  add_foreign_key "assignment_recipients", "memberships", column: "student_membership_id"
  add_foreign_key "assignment_submissions", "assignment_recipients"
  add_foreign_key "assignments", "memberships", column: "teacher_membership_id"
  add_foreign_key "assignments", "organizations"
  add_foreign_key "audit_events", "organizations"
  add_foreign_key "certificates", "memberships", column: "issued_by_membership_id"
  add_foreign_key "certificates", "memberships", column: "recipient_membership_id"
  add_foreign_key "certificates", "memberships", column: "unpublished_by_membership_id", on_delete: :nullify
  add_foreign_key "certificates", "organizations"
  add_foreign_key "class_meeting_feedbacks", "class_meetings"
  add_foreign_key "class_meeting_feedbacks", "memberships", column: "author_membership_id"
  add_foreign_key "class_meeting_students", "class_meetings"
  add_foreign_key "class_meeting_students", "memberships"
  add_foreign_key "class_meetings", "memberships", column: "teacher_membership_id"
  add_foreign_key "class_meetings", "organizations"
  add_foreign_key "course_contents", "course_sections"
  add_foreign_key "course_contents", "courses"
  add_foreign_key "course_enrollments", "courses"
  add_foreign_key "course_enrollments", "memberships"
  add_foreign_key "course_sections", "courses"
  add_foreign_key "courses", "organizations"
  add_foreign_key "material_blocks", "materials"
  add_foreign_key "material_completions", "materials"
  add_foreign_key "material_completions", "memberships"
  add_foreign_key "materials", "courses"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "quiz_answer_ai_grades", "quiz_attempts"
  add_foreign_key "quiz_answer_ai_grades", "quiz_questions"
  add_foreign_key "quiz_answer_ai_transcriptions", "quiz_attempts"
  add_foreign_key "quiz_answer_ai_transcriptions", "quiz_questions"
  add_foreign_key "quiz_answer_feedbacks", "quiz_attempts"
  add_foreign_key "quiz_answer_feedbacks", "quiz_questions"
  add_foreign_key "quiz_answer_options", "quiz_questions"
  add_foreign_key "quiz_answer_overrides", "quiz_attempts"
  add_foreign_key "quiz_answer_overrides", "quiz_questions"
  add_foreign_key "quiz_answer_selections", "quiz_answer_options"
  add_foreign_key "quiz_answer_selections", "quiz_answers"
  add_foreign_key "quiz_answers", "quiz_answer_options"
  add_foreign_key "quiz_answers", "quiz_attempts"
  add_foreign_key "quiz_answers", "quiz_questions"
  add_foreign_key "quiz_attempts", "memberships"
  add_foreign_key "quiz_attempts", "quiz_attempts", column: "superseded_by_attempt_id"
  add_foreign_key "quiz_attempts", "quizzes"
  add_foreign_key "quiz_cloze_responses", "quiz_answers"
  add_foreign_key "quiz_page_blocks", "quiz_pages"
  add_foreign_key "quiz_pages", "quizzes"
  add_foreign_key "quiz_questions", "quiz_pages"
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
  add_foreign_key "support_messages", "support_tickets"
  add_foreign_key "support_tickets", "memberships", column: "escalated_by_membership_id"
  add_foreign_key "support_tickets", "memberships", column: "reporter_membership_id"
  add_foreign_key "support_tickets", "organizations"
end
