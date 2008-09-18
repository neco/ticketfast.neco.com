class AddStatusToFetcherJobs < ActiveRecord::Migration
  def self.up
    add_column :fetcher_jobs, :job_status, :integer, :default => 0
  end

  def self.down
    remove_column :fetcher_jobs, :job_status
  end
end
