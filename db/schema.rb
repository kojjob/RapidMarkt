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

ActiveRecord::Schema[8.0].define(version: 2025_06_14_143352) do
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
    t.index ["status"], name: "index_accounts_on_status"
    t.index ["subdomain"], name: "index_accounts_on_subdomain", unique: true
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
    t.index ["account_id"], name: "index_templates_on_account_id"
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
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

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
  add_foreign_key "subscriptions", "accounts"
  add_foreign_key "tags", "accounts"
  add_foreign_key "templates", "accounts"
  add_foreign_key "users", "accounts"
end
