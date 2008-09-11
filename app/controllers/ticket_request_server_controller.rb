require 'timeout'
require "base64"

class TicketRequestServerController < ApplicationController
  def get_job
    job = nil
    Timeout.timeout(5) {
      job = MiddleMan.worker(:job_queue_worker).get_job
    }
    
    render :text => Base64.encode64(Marshal.dump(job))
  end
  
  def submit_work
    results = Marshal.load(Base64.decode64(params[:results]))
    MiddleMan.worker(:job_queue_worker).async_submit_work(:arg => {:client_key => params[:client_key], :results => results})
    render :text => ''
  end
end
