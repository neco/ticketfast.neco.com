class AddUnfetchedReasonToTickets < ActiveRecord::Migration
  def self.up
    add_column :tickets, :unfetched_reason, :string
  end

  def self.down
    remove_column :tickets, :unfetched_reason
  end
end
