class AddUnparsedToTickets < ActiveRecord::Migration
  def self.up
    add_column :tickets, :unparsed, :boolean, :default => false
  end

  def self.down
    remove_column :tickets, :unparsed
  end
end
