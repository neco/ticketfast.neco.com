class CreateVenues < ActiveRecord::Migration
  def self.up
    create_table :venues do |t|
      t.string :keyword
      t.string :code
      t.string :name
    end
    add_index :venues, :keyword
    add_index :venues, :code
    add_index :venues, :name
  end

  def self.down
    drop_table :venues
  end
end
