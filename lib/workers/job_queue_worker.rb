class JobQueueWorker < BackgrounDRb::MetaWorker
  set_worker_name :job_queue_worker
  
  def create(args = nil)
    @mutex = Mutex.new
    logger.debug 'setting up queue worker'
    @jobs = []
    @job_results = {}
    logger.debug 'cool!'
  end
  
  # This assumes a job never ever fails, is this a problem?
  def get_job
    @mutex.synchronize {
      @jobs.shift || {:action => :instance_eval, :eval_code => "exit"}#{:action => :sleep, :duration => 5}
    }
  end
  
  def submit_work(args)
    @mutex.synchronize {
      logger.debug "** submitting work for client key #{args[:client_key]}"
      client_key, results = args[:client_key], args[:results]
      @job_results[client_key] = results
      logger.debug "** work received"
    }
  end
  
  def fetch_request(args)
    @mutex.synchronize {
      logger.debug "** fetching request: #{args.inspect}"
      client_key, uri, options = args[:client_key], args[:uri], args[:options]
      @jobs << {:action => :fetch_request, :client_key => client_key, :uri => uri, :options => options}
      @job_results[client_key] = false
    }
  end
  
  def fetch_response(args)
    @mutex.synchronize {
      client_key = args[:client_key]
      logger.debug "job status of #{client_key}: #{@job_results[client_key] ? 'received' : 'waiting'}"
    
      @job_results[client_key]
    }
  end
end