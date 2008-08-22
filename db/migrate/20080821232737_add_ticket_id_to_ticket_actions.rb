class AddTicketIdToTicketActions < ActiveRecord::Migration
  def self.up
    add_column :ticket_actions, :ticket_id, :integer
    add_index :ticket_actions, :ticket_id
  end

  def self.down
    remove_column :ticket_actions, :ticket_id
  end
end
