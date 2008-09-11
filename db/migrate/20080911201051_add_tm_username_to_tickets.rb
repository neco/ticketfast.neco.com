class AddTmUsernameToTickets < ActiveRecord::Migration
  def self.up
    add_column :tickets, :tm_account, :string
  end

  def self.down
    remove_column :tickets, :tm_account
  end
end
