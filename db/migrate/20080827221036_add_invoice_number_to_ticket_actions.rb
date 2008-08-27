class AddInvoiceNumberToTicketActions < ActiveRecord::Migration
  def self.up
    add_column :ticket_actions, :invoice_number, :string
  end

  def self.down
    remove_column :ticket_actions, :invoice_number
  end
end
