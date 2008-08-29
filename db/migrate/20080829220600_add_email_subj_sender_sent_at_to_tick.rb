class AddEmailSubjSenderSentAtToTick < ActiveRecord::Migration
  def self.up
    add_column :tickets, :email_subject, :string
    add_column :tickets, :email_from, :string
    add_column :tickets, :email_sent_at, :datetime
    add_index :tickets, :email_subject
    add_index :tickets, :email_from
    add_index :tickets, :email_sent_at
  end

  def self.down
    remove_column :tickets, :email_subject
    remove_column :tickets, :email_from
    remove_column :tickets, :email_sent_at
  end
end
