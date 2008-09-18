class AddClientKeyToFetcher < ActiveRecord::Migration
  def self.up
    add_column :fetcher_jobs, :client_key, :string
  end

  def self.down
    remove_column :fetcher_jobs, :client_key
  end
end
