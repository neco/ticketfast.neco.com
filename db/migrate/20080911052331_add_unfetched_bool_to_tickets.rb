class AddUnfetchedBoolToTickets < ActiveRecord::Migration
  def self.up
    add_column :tickets, :unfetched, :boolean, :default => false
  end

  def self.down
    remove_column :tickets, :unfetched
  end
end
