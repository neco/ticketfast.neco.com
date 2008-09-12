class TmAccountToTmAccountIdTicks < ActiveRecord::Migration
  def self.up
    remove_column :tickets, :tm_account
    add_column :tickets, :tm_account_id, :integer, :default => 0
  end

  def self.down
    remove_column :tickets, :tm_account_id
    add_column :tickets, :tm_account, :string
  end
end
