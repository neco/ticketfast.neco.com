class AddWorkerFieldsToTmAccount < ActiveRecord::Migration
  def self.up
    add_column :tm_accounts, :worker_status, :string
    add_column :tm_accounts, :worker_last_update_at, :datetime
    add_column :tm_accounts, :worker_job_target, :string
  end

  def self.down
    remove_column :tm_accounts, :worker_status
    remove_column :tm_accounts, :worker_last_update_at
    remove_column :tm_accounts, :worker_job_target
  end
end
