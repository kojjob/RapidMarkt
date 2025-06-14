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

ActiveRecord::Schema[8.0].define(version: 2025_06_14_225807) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.string "subdomain", null: false
    t.string "plan", default: "free"
    t.string "status", default: "active"
    t.text "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "business_type"
    t.string "website"
    t.string "industry"
    t.index ["status"], name: "index_accounts_on_status"
    t.index ["subdomain"], name: "index_accounts_on_subdomain", unique: true
  end

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

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.jsonb "details", default: {}
    t.string "ip_address"
    t.text "user_agent"
    t.datetime "performed_at", default: -> { "CURRENT_TIMESTAMP" }
    t.string "resource_type"
    t.bigint "resource_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["details"], name: "index_audit_logs_on_details", using: :gin
    t.index ["performed_at"], name: "index_audit_logs_on_performed_at"
    t.index ["resource_type", "resource_id"], name: "index_audit_logs_on_resource_type_and_resource_id"
    t.index ["user_id", "action"], name: "index_audit_logs_on_user_id_and_action"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "campaign_contacts", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.bigint "contact_id", null: false
    t.datetime "sent_at"
    t.datetime "opened_at"
    t.datetime "clicked_at"
    t.datetime "bounced_at"
    t.datetime "unsubscribed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "failure_reason"
    t.index ["campaign_id"], name: "index_campaign_contacts_on_campaign_id"
    t.index ["contact_id"], name: "index_campaign_contacts_on_contact_id"
  end

  create_table "campaign_tags", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "tag_id"], name: "index_campaign_tags_on_campaign_id_and_tag_id", unique: true
    t.index ["campaign_id"], name: "index_campaign_tags_on_campaign_id"
    t.index ["tag_id"], name: "index_campaign_tags_on_tag_id"
  end

  create_table "campaigns", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name"
    t.string "subject"
    t.string "status"
    t.datetime "scheduled_at"
    t.datetime "sent_at"
    t.decimal "open_rate"
    t.decimal "click_rate"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "template_id"
    t.string "from_name"
    t.string "from_email"
    t.string "reply_to"
    t.string "recipient_type"
    t.string "send_type", default: "now"
    t.string "media_type", default: "text"
    t.text "media_urls"
    t.text "social_platforms"
    t.string "design_theme", default: "modern"
    t.string "background_color", default: "#ffffff"
    t.string "text_color", default: "#1f2937"
    t.string "font_family", default: "Inter"
    t.string "header_image_url"
    t.string "logo_url"
    t.string "call_to_action_text"
    t.string "call_to_action_url"
    t.boolean "social_sharing_enabled", default: false
    t.bigint "user_id", null: false
    t.text "content"
    t.text "preview_text"
    t.index ["account_id"], name: "index_campaigns_on_account_id"
    t.index ["template_id"], name: "index_campaigns_on_template_id"
    t.index ["user_id"], name: "index_campaigns_on_user_id"
  end

  create_table "contact_tags", force: :cascade do |t|
    t.bigint "contact_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_id"], name: "index_contact_tags_on_contact_id"
    t.index ["tag_id"], name: "index_contact_tags_on_tag_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.string "status"
    t.datetime "subscribed_at"
    t.datetime "unsubscribed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_opened_at"
    t.index ["account_id"], name: "index_contacts_on_account_id"
  end

  create_table "onboarding_progresses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "current_step", default: "welcome", null: false
    t.boolean "completed", default: false, null: false
    t.datetime "completed_at"
    t.datetime "started_at", default: -> { "CURRENT_TIMESTAMP" }
    t.integer "completion_percentage", default: 0, null: false
    t.float "total_time_minutes", default: 0.0
    t.jsonb "completed_steps", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["completed"], name: "index_onboarding_progresses_on_completed"
    t.index ["completed_steps"], name: "index_onboarding_progresses_on_completed_steps", using: :gin
    t.index ["current_step"], name: "index_onboarding_progresses_on_current_step"
    t.index ["user_id"], name: "index_onboarding_progresses_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "stripe_subscription_id"
    t.string "stripe_customer_id"
    t.string "plan_name"
    t.string "status"
    t.datetime "current_period_start"
    t.datetime "current_period_end"
    t.datetime "trial_end"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_subscriptions_on_account_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name"
    t.string "color"
    t.text "description"
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_tags_on_account_id"
  end

  create_table "templates", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name"
    t.string "subject"
    t.text "body"
    t.string "template_type"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.text "description"
    t.string "thumbnail_url"
    t.string "design_system", default: "modern"
    t.jsonb "color_scheme", default: {}
    t.jsonb "content_blocks", default: []
    t.jsonb "variables", default: {}
    t.boolean "is_premium", default: false
    t.boolean "is_public", default: false
    t.integer "usage_count", default: 0
    t.decimal "rating", precision: 3, scale: 2, default: "0.0"
    t.text "tags", default: [], array: true
    t.index ["account_id"], name: "index_templates_on_account_id"
    t.index ["color_scheme"], name: "index_templates_on_color_scheme", using: :gin
    t.index ["design_system"], name: "index_templates_on_design_system"
    t.index ["is_public"], name: "index_templates_on_is_public"
    t.index ["tags"], name: "index_templates_on_tags", using: :gin
    t.index ["user_id"], name: "index_templates_on_user_id"
  end

  create_table "user_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "session_id", null: false
    t.string "ip_address"
    t.text "user_agent"
    t.datetime "last_activity_at", null: false
    t.datetime "expires_at", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_user_sessions_on_expires_at"
    t.index ["last_activity_at"], name: "index_user_sessions_on_last_activity_at"
    t.index ["session_id"], name: "index_user_sessions_on_session_id", unique: true
    t.index ["user_id", "active"], name: "index_user_sessions_on_user_id_and_active"
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "role", default: "member"
    t.string "status", default: "active", null: false
    t.index ["account_id", "status"], name: "index_users_on_account_id_and_status"
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["status"], name: "index_users_on_status"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "campaign_contacts", "campaigns"
  add_foreign_key "campaign_contacts", "contacts"
  add_foreign_key "campaign_tags", "campaigns"
  add_foreign_key "campaign_tags", "tags"
  add_foreign_key "campaigns", "accounts"
  add_foreign_key "campaigns", "templates"
  add_foreign_key "campaigns", "users"
  add_foreign_key "contact_tags", "contacts"
  add_foreign_key "contact_tags", "tags"
  add_foreign_key "contacts", "accounts"
  add_foreign_key "onboarding_progresses", "users"
  add_foreign_key "subscriptions", "accounts"
  add_foreign_key "tags", "accounts"
  add_foreign_key "templates", "accounts"
  add_foreign_key "templates", "users"
  add_foreign_key "user_sessions", "users"
  add_foreign_key "users", "accounts"
end
