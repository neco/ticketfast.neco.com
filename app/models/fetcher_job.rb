class FetcherJob < ActiveRecord::Base
  STATUSES = {0 => 'OPEN', 1 => 'WORKING', 2 => 'READY', 3 => 'DELIVERED'}
  
  serialize :job_data
  serialize :job_results
  
  def self.status(name)
    @@statuses_by_name ||= STATUSES.invert
    key = name.to_s.upcase
    @@statuses_by_name[key]
  end
  
  def self.working?
    FetcherJob.count > 0
  end

  def self.fetch_request args
    client_key, job_key, uri, options = args[:client_key], args[:job_key], args[:uri], args[:options]
    job_data = {:action => :fetch_request, :client_key => client_key, :uri => uri, :options => options}
    
    old_job = find_by_job_key(job_key)
    if old_job and old_job.job_status != status(:open)
      old_job.destroy
    end
    
    create :job_data => job_data, :job_target => args[:job_target], :job_key => job_key, :job_status => status(:open), :client_key => client_key
  end
  
  def self.register_client_done(client_key)
    find(:all, :conditions => {:client_key => client_key}).each {|job| job.destroy}
  end

  
  def self.get_job(remote_ip)
    job = find(:first, :conditions => {:job_target => remote_ip, :job_status => status(:open)}, :order => 'created_at asc')
    unless job or find_by_job_target(remote_ip)
      job = find(:first, :conditions => {:job_target => nil, :job_status => status(:open)}, :order => 'created_at asc')
      job.update_attribute(:job_target, remote_ip) if job
    end
    
    if job
      job.update_attribute(:job_status, status(:working))
      job.job_data
    else
      if working?
        {:action => :sleep, :duration => 7}
      else
        {:action => :sleep, :duration => 37}
      end
    end
  end
  
  # should use job key instead of client key, but doesnt matter right now
  def self.submit_work(args)
    client_key, results, remote_ip = args[:client_key], args[:results], args[:remote_ip]
    found_job = find_by_client_key_and_job_target(client_key, remote_ip)
    found_job.update_attributes(:job_results => results, :job_status => status(:ready)) if found_job
  end
  
  def self.fetch_response(args)
    job_key = args[:job_key]
    job = find(:first, :conditions => {:job_key => job_key, :job_status => status(:ready)})
    if job
      job.update_attribute(:job_status, status(:delivered))
      job.job_results.merge(:remote_ip => job.job_target)
    end
  end
end