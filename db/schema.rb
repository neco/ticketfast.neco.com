# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of ActiveRecord to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20080930175329) do

  create_table "events", :force => true do |t|
    t.integer  "venue_id"
    t.string   "code"
    t.string   "name"
    t.string   "event_text"
    t.datetime "occurs_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "events", ["code"], :name => "index_events_on_code"
  add_index "events", ["venue_id"], :name => "index_events_on_venue_id"
  add_index "events", ["name"], :name => "index_events_on_name"
  add_index "events", ["occurs_at"], :name => "index_events_on_occurs_at"

  create_table "fetcher_jobs", :force => true do |t|
    t.text     "job_data"
    t.string   "job_target"
    t.string   "job_key"
    t.text     "job_results", :limit => 16777215
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "job_status",                      :default => 0
    t.string   "client_key"
  end

  create_table "ticket_actions", :force => true do |t|
    t.string   "customer_name"
    t.string   "recipient_email"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "ticket_id"
    t.string   "invoice_number"
  end

  add_index "ticket_actions", ["ticket_id"], :name => "index_ticket_actions_on_ticket_id"

  create_table "tickets", :force => true do |t|
    t.integer  "event_id"
    t.boolean  "viewed"
    t.string   "section"
    t.string   "row"
    t.string   "seat"
    t.string   "purchaser"
    t.string   "order_number"
    t.string   "barcode_number"
    t.string   "event_text"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "unparsed",         :default => false
    t.string   "email_subject"
    t.string   "email_from"
    t.datetime "email_sent_at"
    t.boolean  "unfetched",        :default => false
    t.integer  "tm_account_id",    :default => 0
    t.datetime "tm_order_date"
    t.string   "tm_event_name"
    t.string   "tm_venue_name"
    t.datetime "tm_event_date"
    t.string   "unfetched_reason"
    t.boolean  "archived",         :default => false
  end

  add_index "tickets", ["viewed"], :name => "index_tickets_on_viewed"
  add_index "tickets", ["event_id"], :name => "index_tickets_on_event_id"
  add_index "tickets", ["section"], :name => "index_tickets_on_section"
  add_index "tickets", ["row"], :name => "index_tickets_on_row"
  add_index "tickets", ["seat"], :name => "index_tickets_on_seat"
  add_index "tickets", ["purchaser"], :name => "index_tickets_on_purchaser"
  add_index "tickets", ["order_number"], :name => "index_tickets_on_order_number"
  add_index "tickets", ["barcode_number"], :name => "index_tickets_on_barcode_number"
  add_index "tickets", ["event_text"], :name => "index_tickets_on_event_text"
  add_index "tickets", ["email_subject"], :name => "index_tickets_on_email_subject"
  add_index "tickets", ["email_from"], :name => "index_tickets_on_email_from"
  add_index "tickets", ["email_sent_at"], :name => "index_tickets_on_email_sent_at"

  create_table "tm_accounts", :force => true do |t|
    t.string   "username"
    t.string   "password"
    t.datetime "last_checked"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "disabled",              :default => false
    t.string   "worker_status"
    t.datetime "worker_last_update_at"
    t.string   "worker_job_target"
  end

  create_table "venues", :force => true do |t|
    t.string "keyword"
    t.string "code"
    t.string "name"
  end

  add_index "venues", ["keyword"], :name => "index_venues_on_keyword"
  add_index "venues", ["code"], :name => "index_venues_on_code"
  add_index "venues", ["name"], :name => "index_venues_on_name"

end
