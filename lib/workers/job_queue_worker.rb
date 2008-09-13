class JobQueueWorker < BackgrounDRb::MetaWorker
  set_worker_name :job_queue_worker
  
  def create(args = nil)
    @mutex = Mutex.new
    logger.debug 'setting up queue worker'
    @jobs = []
    @job_results = {}
    set_next_work_time 2.minutes.from_now
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
  def get_job
    @mutex.synchronize {
      if(next_work_time - Time.now < 5 and !working?) 
        logger.debug "Starting work!"
        start_work
      end
        
      @jobs.shift || {:action => :sleep, :duration => ((next_work_time - Time.now < 30) || working? ? 5 : 60 * 10)}
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