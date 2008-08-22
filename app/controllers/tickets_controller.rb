class TicketsController < ApplicationController
  auto_complete_for :event, :name, :select => 'distinct name'

  def index
    @tickets = [] #Ticket.find :all, :order => Ticket.order_clause, :limit => 50, :include => {:event 
#=> :venue}, :conditions => ['viewed != ?', true]
    @viewed_tickets = []#Ticket.find :all, :order => Ticket.order_clause, :limit => 20, :include => 
#{:event => :venue}, :conditions => ['viewed = ?', true]
    @event_dates = Ticket.find_event_dates_by_search("")
  end
  
  
  
  def list
    results =  params[:results] || 5
    startIndex = params[:startIndex] || 0
    sort = params[:sort] || 'ticket.id'
    order_by = sort.gsub(/^.*?\.?([^\.]+)\.([^\.]+)$/, '\1s.\2')
    dir = params[:dir] || 'asc'
    
    find_conditions = ['1=1']
=begin
    [[ignore_event, 'events.name'], 
      [ignore_section, 'ticket_network_ticket_groups.section'],
      [ignore_row, 'ticket_network_ticket_groups.row']].each do |arr, field|
      arr.split(',').each do |val|
        find_conditions[0] += " AND #{field} NOT LIKE ?"
        find_conditions << "%#{val.strip}%"
      end
    end
=end

    find_include = {:event => :venue}
        
    @tickets = Ticket.find :all,
      :include => find_include, 
      :conditions => find_conditions,
      :offset => startIndex, 
      :limit => results,
      :order => "#{order_by} #{dir}"
      
    ticket_json = @tickets.to_json(
      :only => [:id, :event_id, :section, :row, :seat], :include => {
        :event => {:only => [:name, :venue_id, :occurs_at, :code], :include => {
          :venue => {:only => :name}
        } }
      }
    )
    
    # need to come up with or find a nice way of manipulating JSON without using string interpolation...
    render :text => %[{"totalRecords":#{Ticket.find(:all, :include => find_include, :conditions => find_conditions).size},
      "recordsReturned":#{@tickets.size},
      "startIndex":#{startIndex},
      "sort":"#{sort}",
      "dir":"#{dir}",
      "records":#{ticket_json}}]
  end
  
  

  def check_mail
    tickets = IncomingMailHandler.process_new_mail
    flash[:success] = "#{tickets} were added."
    redirect_to :action => "index"
  end
  
  # ajax only, returns partial
  def get_ticket_data
    @ticket = Ticket.find params[:id]
    render :partial => 'ticket_data' if request.xhr?
  end
  
  def event
    @event = Event.find params[:id]
    @tickets = @event.tickets.find(:all, :conditions => ['viewed = ?', false])
    @viewed_tickets = @event.tickets.find(:all, :conditions => ['viewed = ?', true])
    render :action => "index"
  end
  
  def mark_new
    Ticket.find(params[:id]).unview!
    render_text ""
  end

  def edit_field
    ticket = Ticket.find params[:id]
    ticket[params[:field]] = params[:value]
    ticket.save
    # This ternary belongs in the view
    render :text => (!ticket[params[:field]].blank? ? ticket[params[:field]] : '-')
  end

  def view_queue
    @tickets = Ticket.find :all, :conditions => 'event_id = 0 or event_id is null', :order => 'created_at desc', :limit => 50
    @tic = Ticket.find :first, :conditions => 'event_id > 5'
  end
  
  def get_queue_date_partial
    @ticket = Ticket.find params[:ticket_id]
    render :partial => 'get_queue_date' 
  end

  def queue_set_event
    ticket = Ticket.find params[:id]
    event = nil
    if params[:event_id] && (params[:custom_date].nil? or params[:custom_date][ticket.id.to_s].empty?)
      event = Event.find params[:event_id]
    elsif params[:custom_date][ticket.id.to_s].empty?
      render :text => 'You must select an event date or pick a new date.'
      return
    elsif params[:event_names][ticket.id.to_s].empty?
      render :text => 'You must choose an event name.'
      return
    else
      date = DateTime.parse "#{params[:custom_date][ticket.id.to_s]} #{params[:date][:hour]}:#{params[:date][:minute]}" 
      event = Event.create :occurs_at => date, :name => params[:event_names][ticket.id.to_s]
    end
    ticket.event = event
    ticket.save
    render :text => %[Success, assigned to #{event.name} which occurs #{event.occurs_at.strftime "%m/%d %I:%M %P"}<br /><br /><a href="javascript:eventAssign('#{event.name}', #{event.id}, #{ticket.id})">Assign to other tickets</a>]
  end

  def search_by_fields
    conditions = '1=1'
    conditions += " AND events.name LIKE '#{params[:event][:name]}%' " if params[:event][:name] and !params[:event][:name].empty?
    conditions += " AND events.code LIKE '#{params[:event_code]}%' " if params[:event_code] and !params[:event_code].empty?
    [:section, :row, :seat, :order_number, :barcode_number].each do |field|
      conditions += " AND tickets.#{field.to_s} = '#{params[field].gsub(/'/, "\\'")}'" unless !params[field] or params[field].empty?
    end
    conditions_without_date = conditions
    unless params[:event_date] == "0"
      datetime = Time.parse params[:event_date]
      conditions += " AND events.occurs_at = '#{datetime.to_s :db}'"
    end
    viewed_conditions = conditions
    if params[:customer_name] and !params[:customer_name].empty?
      viewed_conditions += " AND ticket_actions.customer_name LIKE '%#{params[:customer_name].gsub(/'/, "\\'")}%'"
      @tickets = nil    
    else
      @tickets = Ticket.find_by_search('', "#{conditions} AND viewed!=1")
    end
    @viewed_tickets = Ticket.find_by_search('', "#{viewed_conditions} AND viewed=1", (@tickets.nil? ? 
true : false) )
    if @tickets.nil?
      @tickets, @viewed_tickets = @viewed_tickets, []
    end
    @event_dates = Ticket.find_event_dates_by_search('', "#{conditions_without_date}")
    unless request.xhr?
      render :action => "index"
    else
      render :partial => "list"
    end
  end
  
  def email_or_download_tickets
    # Create ticket actions to log this action
    ta_proto = TicketAction.new :customer_name => params[:customer_name]
    ticket_actions = []
    params[:tickets].each do |ticket_id|
      ticket_actions << ta_proto.clone
      ticket_actions.last.ticket_id = ticket_id
    end
    
    if !params[:tickets]
      redirect_to :action => "index"
      return
    elsif params[:tickets].size > 1
      params[:tickets].size > 1
      dest_filepath = create_composite_pdf params[:tickets]
    else params[:tickets].size == 1
      ticket = Ticket.find(params[:tickets].first)
      ticket.view!
      dest_filepath = ticket.pdf_filepath
    end
    if params[:recipient].empty?
      send_file dest_filepath, :filename => "tickets.pdf"
    else
      ticket_actions.each do |ta|
        ta.recipient_email = params[:recipient]
      end
      TicketsMailerQueue.push(params[:recipient], dest_filepath, params[:subject])
      flash[:success] = "Your ticket PDF has been queued for e-mail.  It should go out in the next 10 
minutes."
      redirect_to :action => "index"
    end
    ticket_actions.each do |ta| ta.save; end
  end

  def preview_pdf
    send_file Ticket.find(params[:id]).pdf_filepath
  end
 
  def create_composite_pdf ticket_ids
    ticket_ids.each do |id|
      Ticket.find(id).view!
    end
    src_path = "#{RAILS_ROOT}/#{Setting['pdf_dir']}"
    dest_filepath = "#{RAILS_ROOT}/#{Setting['tmp_dir']}/all_#{ticket_ids.first}.pdf"
    `pdftk #{ticket_ids.collect{|t| "#{src_path}/#{t}.pdf "}.join} cat output #{dest_filepath}`
    dest_filepath
  end
  
  def delete_all
    Ticket.destroy_all
    redirect_to :action => "index"
  end
end
