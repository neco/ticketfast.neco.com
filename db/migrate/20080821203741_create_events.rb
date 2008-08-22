class CreateEvents < ActiveRecord::Migration
  def self.up
    create_table :events do |t|
      t.integer :venue_id
      t.string :code
      t.string :name
      t.string :event_text
      t.datetime :occurs_at
      t.timestamps
    end
    add_index :events, :code
    add_index :events, :venue_id
    add_index :events, :name
    add_index :events, :occurs_at
  end

  def self.down
    drop_table :events
  end
end
