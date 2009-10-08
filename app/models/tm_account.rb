class TmAccount < ActiveRecord::Base
  has_many :tickets

  named_scope :enabled, :conditions => {:disabled => false}
  named_scope :queued, :conditions => {:worker_status => 'queued'}

  def worker_status_full
    if worker_job_target
      "#{worker_status} on #{worker_job_target}"
    else
      worker_status
    end
  end
end
