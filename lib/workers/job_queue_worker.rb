class JobQueueWorker < BackgrounDRb::MetaWorker
  set_worker_name :job_queue_worker
  
  def create(args = nil)
    @mutex = Mutex.new
    logger.debug 'setting up queue worker'
    @jobs = []
    @targetted_jobs = {}
    @job_results = {}
    set_next_work_time 15.seconds.from_now
    logger.debug 'cool!'
  end
  
  def set_next_work_time(time)
    logger.debug "SETTING NEXT WORK TIME! #{time.inspect}"
    @next_work_time = time
  end
  
  def register_work_done
    logger.debug "REGISTERED: work is done"
    logger.debug "Next work time: #{next_work_time.inspect}"
    @still_working = false
  end
  
  def next_work_time
    @next_work_time
  end
  
  def start_work
    set_next_work_time 4.hours.from_now
    @still_working = true
    MiddleMan.worker(:ticket_request_worker).async_save_unseen_tickets
  end
  
  def working?
    @still_working
  end
  
  # This assumes a job never ever fails, is this a problem?
  def get_job(remote_ip)
    @mutex.synchronize {
      if(next_work_time - Time.now < 5 and !working?) 
        logger.debug "Starting work!"
        start_work
      end
      if @targetted_jobs[remote_ip].size > 0
        logger.debug "Getting targetted job for #{remote_ip}"
        return @targetted_jobs[remote_ip].shift
      end
      @jobs.shift || {:action => :sleep, :duration => ((next_work_time - Time.now < 30) || working? ? 5 : 30)}
    }
  end
  
  def submit_work(args)
    @mutex.synchronize {
      logger.debug "** submitting work for client key #{args[:client_key]} and ip #{args[:remote_ip]}" 
      client_key, results = args[:client_key], args[:results]
      @job_results[client_key] = results.merge(:remote_ip => args[:remote_ip])
      logger.debug "** work received"
    }
  end
  
  def fetch_request(args)
    @mutex.synchronize {
      logger.debug "** fetching request: #{args.inspect}"
      client_key, uri, options = args[:client_key], args[:uri], args[:options]
      job_data = {:action => :fetch_request, :client_key => client_key, :uri => uri, :options => options}
      if args[:job_target]
        logger.debug "Creating targetted job for #{args[:job_target]}"
        @targetted_jobs[args[:job_target]] ||= []
        @targetted_jobs[args[:job_target]] << job_data
      else
        logger.debug "Creating normal job"
        @jobs << job_data
      end
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