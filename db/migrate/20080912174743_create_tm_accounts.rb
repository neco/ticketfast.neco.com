class CreateTmAccounts < ActiveRecord::Migration
  def self.up
    create_table :tm_accounts do |t|
      t.string :username
      t.string :password
      t.datetime :last_checked

      t.timestamps
    end
  end

  def self.down
    drop_table :tm_accounts
  end
end
