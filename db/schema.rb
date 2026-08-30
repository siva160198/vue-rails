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

ActiveRecord::Schema[8.1].define(version: 2026_08_30_055000) do
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

  create_table "admin_approvals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action_key", null: false
    t.datetime "approved_at"
    t.bigint "approver_id"
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "payload_digest", null: false
    t.jsonb "payload_summary", default: {}, null: false
    t.bigint "requester_id", null: false
    t.datetime "updated_at", null: false
    t.index ["action_key", "payload_digest", "requester_id"], name: "index_admin_approvals_lookup"
    t.index ["approver_id"], name: "index_admin_approvals_on_approver_id"
    t.index ["expires_at"], name: "index_admin_approvals_on_expires_at"
    t.index ["requester_id"], name: "index_admin_approvals_on_requester_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "actor_id"
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.datetime "created_at", null: false
    t.string "entry_digest"
    t.string "ip_address"
    t.jsonb "metadata", default: {}, null: false
    t.string "previous_digest"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["actor_id"], name: "index_audit_logs_on_actor_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["entry_digest"], name: "index_audit_logs_on_entry_digest", unique: true
  end

  create_table "email_change_challenges", force: :cascade do |t|
    t.integer "attempts_count", default: 0, null: false
    t.string "code_digest", null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "expires_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_email_change_challenges_on_expires_at"
    t.index ["user_id"], name: "index_email_change_challenges_on_user_id"
  end

  create_table "login_attempts", force: :cascade do |t|
    t.boolean "captcha_verified", default: false, null: false
    t.datetime "created_at", null: false
    t.string "device_digest"
    t.string "email_digest", null: false
    t.string "ip_address", null: false
    t.integer "risk_score", default: 0, null: false
    t.boolean "successful", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_login_attempts_on_created_at"
    t.index ["device_digest", "created_at"], name: "index_login_attempts_on_device_digest_and_created_at"
    t.index ["email_digest", "created_at"], name: "index_login_attempts_on_email_digest_and_created_at"
    t.index ["ip_address", "created_at"], name: "index_login_attempts_on_ip_address_and_created_at"
  end

  create_table "login_challenges", force: :cascade do |t|
    t.integer "attempts_count", default: 0, null: false
    t.string "code_digest", null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_login_challenges_on_expires_at"
    t.index ["user_id"], name: "index_login_challenges_on_user_id"
  end

  create_table "password_histories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "created_at"], name: "index_password_histories_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_password_histories_on_user_id"
  end

  create_table "permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_permissions_on_key", unique: true
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
    t.boolean "system", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_roles_on_key", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "ip_address"
    t.datetime "last_seen_at", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "step_up_challenges", force: :cascade do |t|
    t.integer "attempts_count", default: 0, null: false
    t.string "code_digest", null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "purpose", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_step_up_challenges_on_expires_at"
    t.index ["user_id", "purpose"], name: "index_step_up_challenges_on_user_id_and_purpose"
    t.index ["user_id"], name: "index_step_up_challenges_on_user_id"
  end

  create_table "step_up_grants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "authentication_version", null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "purpose", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_step_up_grants_on_expires_at"
    t.index ["user_id"], name: "index_step_up_grants_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "authentication_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "email_verified_at"
    t.integer "failed_login_attempts", default: 0, null: false
    t.string "first_name", limit: 80
    t.string "last_name", limit: 80
    t.datetime "locked_until"
    t.string "password_digest", null: false
    t.string "pending_email_revert_address"
    t.string "pending_email_revert_digest"
    t.datetime "pending_email_revert_expires_at"
    t.text "phone"
    t.jsonb "recovery_code_digests", default: [], null: false
    t.string "role", default: "member", null: false
    t.datetime "security_alerted_at"
    t.datetime "totp_enabled_at"
    t.string "totp_secret"
    t.datetime "updated_at", null: false
    t.string "webauthn_user_handle"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["webauthn_user_handle"], name: "index_users_on_webauthn_user_handle", unique: true
  end

  create_table "webauthn_credentials", force: :cascade do |t|
    t.string "authenticator_attachment"
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.datetime "last_used_at"
    t.string "nickname", null: false
    t.text "public_key", null: false
    t.integer "sign_count", default: 0, null: false
    t.jsonb "transports", default: [], null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["external_id"], name: "index_webauthn_credentials_on_external_id", unique: true
    t.index ["user_id"], name: "index_webauthn_credentials_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "admin_approvals", "users", column: "approver_id"
  add_foreign_key "admin_approvals", "users", column: "requester_id"
  add_foreign_key "audit_logs", "users", column: "actor_id"
  add_foreign_key "email_change_challenges", "users"
  add_foreign_key "login_challenges", "users"
  add_foreign_key "password_histories", "users"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "sessions", "users"
  add_foreign_key "step_up_challenges", "users"
  add_foreign_key "step_up_grants", "users"
  add_foreign_key "users", "roles", column: "role", primary_key: "key"
  add_foreign_key "webauthn_credentials", "users"
end
