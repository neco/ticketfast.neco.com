require 'timeout'
require "base64"

class TicketRequestServerController < ApplicationController
  def get_job
    job = nil
    Timeout.timeout(5) {
      job = FetcherJob.get_job(request.remote_ip)
    }
    
    render :text => Base64.encode64(Marshal.dump(job))
  end
  
  def submit_work
    results = Marshal.load(Base64.decode64(params[:results]))
    FetcherJob.submit_work(:job_key => params[:client_key], :results => results, :remote_ip => request.remote_ip)
    render :text => ''
  end
end
