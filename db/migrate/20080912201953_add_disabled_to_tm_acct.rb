class AddDisabledToTmAcct < ActiveRecord::Migration
  def self.up
    add_column :tm_accounts, :disabled, :boolean, :default => false
  end

  def self.down
    remove_column :tm_accounts, :disabled
  end
end
