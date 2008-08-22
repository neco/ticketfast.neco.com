class CreateTicketActions < ActiveRecord::Migration
  def self.up
    create_table :ticket_actions do |t|
      t.string :customer_name
      t.string :recipient_email
      t.timestamps
    end
  end

  def self.down
    drop_table :ticket_actions
  end
end
