class AddArchivedToTickets < ActiveRecord::Migration
  def self.up
    add_column :tickets, :archived, :boolean, :default => false
  end

  def self.down
    remove_column :tickets, :archived
  end
end
