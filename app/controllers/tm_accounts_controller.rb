class TmAccountsController < ApplicationController
  def index
    @tm_accounts = TmAccount.find :all
    @js_includes = ['dt_defs', 'tm_accounts_dt_defs']
  end
  
  # Action called by the YUI datatable
  def list
    results =  params[:results] || 5
    startIndex = params[:startIndex] || 0
    sort = params[:sort] || 'tm_account.username'
    order_by = sort.gsub(/^.*?\.?([^\.]+)\.([^\.]+)$/, '\1s.\2')
    dir = params[:dir] || 'asc'
    
    find_include = {}
    
    find_conditions = []
        
    @tm_accounts = TmAccount.find :all,
      :include => find_include, 
      :conditions => find_conditions,
      :offset => startIndex, 
      :limit => results,
      :order => "#{order_by} #{dir}"      
      
    tm_account_json = '[' + @tm_accounts.collect{|t| %({"id":#{t.id},"username":"#{t.username}","password":"#{t.password}","worker_last_update_at":"#{t.attributes_before_type_cast['worker_last_update_at'].gsub('-','/')}","disabled":#{t.disabled},"worker_status":"#{t.worker_status}","worker_job_target":"#{t.worker_job_target}","fetched_count":#{t.tickets.fetched.size},"unfetched_count":#{t.tickets.unfetched.size}})}.join(',') + ']'
    
    render :text => %[{"totalRecords":#{TmAccount.count(:all, :include => find_include, :conditions => find_conditions)},
      "recordsReturned":#{@tm_accounts.size},
      "startIndex":#{startIndex},
      "sort":"#{sort}",
      "dir":"#{dir}",
      "records":#{tm_account_json}}]
  end
  
  def create
    @tm_account = TmAccount.create params[:tm_account]
    redirect_to :action => 'index'
  end
  
  def destroy
    TmAccount.find(params[:id]).destroy
    redirect_to :action => 'index'
  end
  
  def manual_fetch
    MiddleMan.worker(:ticket_request_worker).async_save_unseen_tickets(:arg => params[:id])
    redirect_to :action => 'index'
  end
  
  def toggle_disabled
    @tm_account = TmAccount.find(params[:id])
    @tm_account.disabled = @tm_account.disabled? ? false : true
    @tm_account.save
    redirect_to :action => 'index'
  end
  
  def list_unfetched
    @tm_account = TmAccount.find(params[:id])
    @tickets = @tm_account.tickets.unfetched
    @unfetched = true
    render :action => 'list_tm_tickets'
  end
  
  def list_fetched
    @tm_account = TmAccount.find(params[:id])
    @tickets = @tm_account.tickets.fetched
    render :action => 'list_tm_tickets'
  end
end
