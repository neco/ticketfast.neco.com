class CreateTickets < ActiveRecord::Migration
  def self.up
    create_table :tickets do |t|
      t.integer :event_id
      t.boolean :viewed
      t.string :section
      t.string :row
      t.string :seat
      t.string :purchaser
      t.string :order_number
      t.string :barcode_number
      t.string :event_text
      t.timestamps
    end
    add_index :tickets, :viewed
    add_index :tickets, :event_id
    add_index :tickets, :section
    add_index :tickets, :row
    add_index :tickets, :seat
    add_index :tickets, :purchaser
    add_index :tickets, :order_number
    add_index :tickets, :barcode_number
    add_index :tickets, :event_text
  end

  def self.down
    drop_table :tickets
  end
end
