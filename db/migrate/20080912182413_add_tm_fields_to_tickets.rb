class AddTmFieldsToTickets < ActiveRecord::Migration
  def self.up
    add_column :tickets, :tm_order_date, :datetime
    add_column :tickets, :tm_event_name, :string
    add_column :tickets, :tm_venue_name, :string
    add_column :tickets, :tm_event_date, :datetime
  end

  def self.down
    remove_column :tickets, :tm_order_date
    remove_column :tickets, :tm_event_name
    remove_column :tickets, :tm_venue_name
    remove_column :tickets, :tm_event_date
  end
end