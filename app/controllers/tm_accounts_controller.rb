class TmAccountsController < ApplicationController
  auto_complete_for :tm_account, :username, :select => 'distinct username'
  
  def auto_complete_for_ticket_tm_event_name
    find_options = { 
      :conditions => [ "tm_event_name LIKE ?", '%' + params[:ticket][:tm_event_name].downcase + '%' ], 
      :order => "tm_event_name ASC",
      :limit => 10,
      :select => 'distinct tm_event_name' }

    @items = Ticket.unfetched.find(:all, find_options)

    render :inline => "<%= auto_complete_result @items, 'tm_event_name' %>"
  end
  
  def auto_complete_for_ticket_tm_venue_name
    find_options = { 
      :conditions => [ "tm_venue_name LIKE ?", '%' + params[:ticket][:tm_venue_name].downcase + '%' ], 
      :order => "tm_venue_name ASC",
      :limit => 10,
      :select => 'distinct tm_venue_name' }

    @items = Ticket.unfetched.find(:all, find_options)

    render :inline => "<%= auto_complete_result @items, 'tm_venue_name' %>"
  end
  
  def index
    @tm_accounts = TmAccount.find :all
    @js_includes = ['dt_defs', 'tm_accounts_dt_defs']
  end
  
  def archive_unfetched
    Ticket.find(params[:id]).update_attribute(:archived, true)
    redirect_to :action => 'unfetched'
  end
  
  def unfetched
    @js_includes = ['dt_defs', 'tm_accounts_tickets_dt_defs']
  end
  
  def get_event_dates
    @dates = Ticket.unfetched.find_all_by_tm_event_name(params[:tm_event_name], :order => 'tm_event_date').collect{|t| t.tm_event_date}.uniq!
    render :partial => 'tm_event_dates' if request.xhr?
  end
  
  # Action called by the YUI datatable
  def dt_unfetched
    results =  params[:results] || 5
    startIndex = params[:startIndex] || 0
    sort = params[:sort] || 'ticket.created_at'
    order_by = sort.gsub(/^.*?\.?([^\.]+)\.([^\.]+)$/, '\1s.\2')
    dir = params[:dir] || 'desc'
    
    find_include = :tm_account
    
    find_conditions = ['1=1']

    if(params[:tm_event_name] and !params[:tm_event_name].blank?)
      find_conditions[0] += ' AND tm_event_name = ?'
      find_conditions << params[:tm_event_name].strip
    end
    if(params[:tm_venue_name] and !params[:tm_venue_name].blank?)
      find_conditions[0] += ' AND tm_venue_name = ?'
      find_conditions << params[:tm_venue_name].strip
    end
    if(params[:username] and !params[:username].blank?)
      find_conditions[0] += ' AND tm_accounts.username = ?'
      find_conditions << params[:username].strip
    end
    if(params[:event_date] and params[:event_date] != '0')
      find_conditions[0] += ' AND tm_event_date = ?'
      find_conditions << Date.parse(params[:event_date])
    end
    
    
    @tickets = Ticket.unfetched.find :all,
      :include => find_include, 
      :conditions => find_conditions,
      :offset => startIndex, 
      :limit => results,
      :order => "#{order_by} #{dir}"      
      
    ticket_json = '[' + @tickets.collect{|t| %({"id":#{t.id},"order_number":"#{t.order_number}","tm_order_date":"#{t.attributes_before_type_cast['tm_order_date'].gsub('-','/')}","tm_event_name":"#{t.tm_event_name.gsub('"','\\"') if t.tm_event_name}","tm_venue_name":"#{t.tm_venue_name.gsub('"','\\"') if t.tm_venue_name}","tm_event_date":"#{t.attributes_before_type_cast['tm_event_date'].gsub('-','/')}","unfetched_reason":"#{t.unfetched_reason.gsub('"','\\"').gsub("\n",' ') if t.unfetched_reason}","tm_account":{"username":"#{t.tm_account.username if t.tm_account}"}})}.join(',') + ']'
    
    render :text => %[{"totalRecords":#{Ticket.unfetched.count(:all, :include => find_include, :conditions => find_conditions)},
      "recordsReturned":#{@tickets.size},
      "startIndex":#{startIndex},
      "sort":"#{sort}",
      "dir":"#{dir}",
      "records":#{ticket_json}}]
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
    find_conditions = ['tm_accounts.username like ?', "%#{params[:query]}%"] if params[:query]
        
    @tm_accounts = TmAccount.find :all,
      :include => find_include, 
      :conditions => find_conditions,
      :offset => startIndex, 
      :limit => results,
      :order => "#{order_by} #{dir}"      
      
    tm_account_json = '[' + @tm_accounts.collect{|t| %({"id":#{t.id},"username":"#{t.username}","password":"#{t.password}","worker_last_update_at":"#{t.attributes_before_type_cast['worker_last_update_at'].gsub('-','/') if t.attributes_before_type_cast['worker_last_update_at']}","disabled":#{t.disabled},"worker_status":"#{t.worker_status}","worker_job_target":"#{t.worker_job_target}","fetched_count":#{t.tickets.fetched.size},"unfetched_count":#{t.tickets.unfetched.size}})}.join(',') + ']'
    
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
    if FetcherJob.count > 0
      TmAccount.find(params[:id]).update_attribute(:worker_status, 'queued')
    else
      MiddleMan.worker(:ticket_request_worker).async_save_unseen_tickets(:arg => params[:id])
    end
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
