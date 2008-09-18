class CreateFetcherJobs < ActiveRecord::Migration
  def self.up
    create_table :fetcher_jobs do |t|
      t.text :job_data
      t.string :job_target
      t.string :job_key
      t.text :job_results, :limit => 2.megabytes
      t.timestamps
    end
  end

  def self.down
    drop_table :fetcher_jobs
  end
end
