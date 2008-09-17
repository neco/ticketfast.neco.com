class JobStatusWorker < BackgrounDRb::MetaWorker
  set_worker_name :job_status_worker
  
  def create(args = nil)
    logger.debug 'setting up status worker'
    @job_targets = []
    logger.debug 'cool!'
  end

  def add_job_target(args)
    logger.debug "ADDING JOB TARGET: #{args[:remote_ip]}"
    @job_targets << args[:remote_ip]
  end
  
  def remove_job_target(args)
    logger.debug "REMOVING JOB TARGET: #{args[:remote_ip]}"
    @job_targets.delete(args[:remote_ip])
  end
  
  def get_job_targets
    @job_targets
  end
  
  def target_in_use?(args)
    logger.debug "TARGET IN USE? #{args[:remote_ip]}"
    @job_targets.include?(args[:remote_ip])
  end
    
end