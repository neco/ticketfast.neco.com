class TicketsController < ApplicationController
  auto_complete_for :event, :name, :select => 'distinct name'
  
  def index
    @js_includes = ['dt_defs', 'tickets_dt_defs']
  end
  
  # Action called by the YUI datatable
  def list
    results =  params[:results] || 5
    startIndex = params[:startIndex] || 0
    sort = params[:sort] || 'ticket.id'
    order_by = sort.gsub(/^.*?\.?([^\.]+)\.([^\.]+)$/, '\1s.\2')
    dir = params[:dir] || 'asc'
    
    find_include = {:event => :venue}
    
    find_conditions = ['unparsed = ?', params[:unparsed] ? true : false]
    params[:conditions].each do |field,val|
      find_conditions[0] += " AND #{field} LIKE ?"
      find_conditions << "#{val.strip}%"
    end if params[:conditions]
    
    if(params[:event_name] and !params[:event_name].blank?)
      find_conditions[0] += ' AND events.name = ?'
      find_conditions << params[:event_name].strip
    end
    
    if(params[:event_code] and !params[:event_code].blank?)
      find_conditions[0] += ' AND events.code = ?'
      find_conditions << params[:event_code].strip
    end
    
    if(params[:event_id] and !params[:event_id].blank?)
      find_conditions[0] += ' AND events.id = ?'
      find_conditions << params[:event_id].strip
    end
    
    if(params[:customer_name] and !params[:customer_name].blank?)
      find_conditions[0] += ' AND ticket_actions.customer_name = ?'
      find_conditions << params[:customer_name].strip
      find_include = [find_include, :ticket_actions]
    end
    
    unless(params[:show_all] or params[:viewed_only]) 
      find_conditions[0] += ' AND (viewed IS NULL OR viewed = ?)'    
      find_conditions << false
    end
    
    if(params[:viewed_only]) 
      find_conditions[0] += ' AND viewed = ?'    
      find_conditions << true
    end
        
    @tickets = Ticket.find :all,
      :include => find_include, 
      :conditions => find_conditions,
      :offset => startIndex, 
      :limit => results,
      :order => "#{order_by} #{dir}"
      
    ticket_json = @tickets.to_json(
      :only => [:id, :event_id, :section, :row, :seat, :email_sent_at, :email_from, :email_subject], :include => {
        :event => {:only => [:name, :venue_id, :occurs_at, :code], :include => {
          :venue => {:only => :name}
        } }
      }
    )
    
    render :text => %[{"totalRecords":#{Ticket.count(:all, :include => find_include, :conditions => find_conditions)},
      "recordsReturned":#{@tickets.size},
      "startIndex":#{startIndex},
      "sort":"#{sort}",
      "dir":"#{dir}",
      "records":#{ticket_json}}]
  end
  
  def get_details
    @ticket = Ticket.find params[:id]
    render :partial => 'ticket_data' if request.xhr?
  end
  
  def edit
    @ticket = Ticket.find params[:id]
    render :partial => 'edit' if request.xhr?
  end
  
  def update
    @ticket = Ticket.find params[:ticket][:id]
    @ticket.update_attributes!(params[:ticket])
    if(params[:event_id] and params[:event_id] != '0')
      @ticket.event = Event.find(params[:event_id])
    elsif(params[:event][:name])
      @ticket.event = Event.new(params[:event])
      @ticket.event.occurs_at = Date.parse(params[:event_date_text])
    end
    if(@ticket.event)
      @ticket.unparsed = false
    end
    @ticket.save
    
    render :text => ''
  end
  
  def get_event_dates
    @events = Event.find_all_by_name(params[:event_name])
    @event_id = params[:event_id]
    @custom = params[:custom_opt] # show 'custom' instead of 'view all'
    render :partial => 'event_dates' if request.xhr?
  end
  
  
  

  def check_mail
    tickets = IncomingMailHandler.process_new_mail
    flash[:success] = "#{tickets} were added."
    redirect_to :action => "index"
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
    @js_includes = ['dt_defs', 'queue_dt_defs']
    #@tickets = Ticket.unparsed.find(:all, :order => 'created_at desc', :limit => 50)
  end
  
  def view_text
    @ticket = Ticket.find params[:id]
    out_path = "#{RAILS_ROOT}/tmp/#{@ticket.id}_text}"
    `pdftotext #{@ticket.pdf_filepath} #{out_path}`
    pdf_text = File.read(out_path)
    `rm -f #{out_path}`
    send_data pdf_text, :filename => "ticket_#{@ticket.id}.txt"
  end
  
  def parse
    @ticket = Ticket.find params[:id]
    ticket_parser = TicketParser.new(@ticket)
    ticket_parser.parse!
    out = '<pre>'
    if(ticket_parser.parsed?) 
      out += "Ticket format: #{ticket_parser.ticket_format}\n\n"
      out += "Ticket: #{ticket_parser.parsed_ticket.inspect}\n\n"
      out += "Event: #{ticket_parser.parsed_event.inspect}\n\n"
      out += "Venue code: #{ticket_parser.parsed_venue_code.inspect}\n\n"
      out += "Parse and save: <a href='/tickets/parse_and_save/#{@ticket.id}'>save</a>"
    else
      out += "Unable to parse"
    end
    out += '</pre>'
    render :text => out
  end
  
  def parse_and_save
    @ticket = Ticket.find params[:id]
    ticket_parser = TicketParser.new(@ticket).parse_and_save!
    render :text => @ticket.attributes.inspect
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

  def email_or_download_tickets
    if !params[:tickets] or params[:tickets].size == 0
      redirect_to :action => "index"
      return
    end
    
    # Create ticket actions to log this action
    ta_proto = TicketAction.new :customer_name => params[:customer_name], :invoice_number => params[:invoice_number]
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
      TicketsMailer.deliver_attached_pdf params[:recipient], dest_filepath, params[:subject]
      redirect_to :action => "index"
    end
    ticket_actions.each do |ta| ta.save; end
  end

  def preview_pdf
    send_file Ticket.find(params[:id]).pdf_filepath
  end

  def quickview_ticket
    @ticket = Ticket.find(params[:id])
    @ticket.create_quickview! unless File.exists?(@ticket.jpg_filepath)
    send_file @ticket.jpg_filepath
  end
  
private
  def create_composite_pdf ticket_ids
    ticket_ids.each do |id|
      Ticket.find(id).view!
    end
    src_path = "#{RAILS_ROOT}/#{Setting['pdf_dir']}"
    dest_filepath = "#{RAILS_ROOT}/#{Setting['tmp_dir']}/all_#{ticket_ids.first}.pdf"
    `pdftk #{ticket_ids.collect{|t| "#{src_path}/#{t}.pdf "}.join} cat output #{dest_filepath}`
    dest_filepath
  end
end
