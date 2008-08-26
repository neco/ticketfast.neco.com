class TicketParser
  attr_accessor :parsed_ticket, :parsed_event, :parsed_venue_code, :pdf_text, :ticket_format, :saved_ticket, :created_event, :ticket_obj
  
  # initialize with pdf text or a ticket object
  def initialize(mixed)
    if mixed.class == String
      self.pdf_text = mixed
    elsif mixed.class == Ticket
      out_path = "#{RAILS_ROOT}/tmp/#{mixed.id}_text}"
      system "pdftotext #{mixed.pdf_filepath} #{out_path} >& /dev/null"
      self.pdf_text = File.read(out_path)
      self.ticket_obj = mixed
      `rm -f #{out_path}`
    end
    self.parsed_event = self.parsed_ticket = {}
  end
  
  def parse_and_save!
    parse!
    if parsed?
      ticket_obj.nil? ? create_from_parse! : update_from_parse!(ticket_obj)
    end
  end
  
  def parse!
    parsed_data = nil
    %w(default mlb_2008 mlb no_purchaser mlb_alt mlb_2007 exchange).each do |format|
      parsed_data = send('parse_' + format)
      if parsed?
        self.ticket_format = format
        break
      end
    end
    if parsed?
      self.parsed_venue_code = parsed_event[:code].match(/^[^0-9]+/)[0] unless parsed_venue_code or !parsed_event[:code]
      parse_event_date!
    end
  end
  
  def create_from_parse!
    update_from_parse!(Ticket.new)
  end
  
  def update_from_parse!(tic)
    event = Event.find_all_by_code(parsed_event[:code])
    
    # Create event if the event code does not exist yet
    if event.size == 0 and parsed_event[:code]
      event = Event.create(parsed_event)
      self.created_event = event
    else
      event = event.first
    end
    
    self.parsed_ticket[:event_id] = event.id if event
    self.saved_ticket = tic
    saved_ticket.update_attributes(parsed_ticket.merge({:unparsed => false}))
    
    event.set_venue!(parsed_venue_code) if event and !event.venue
    saved_ticket.save
  end
  
  def parsed?
    !parsed_ticket.empty? && !parsed_event.empty?
  end

private

  def parse_event_date!
    begin
      self.parsed_event[:occurs_at] = DateTime.parse(parsed_ticket[:event_text])
    rescue # Failed, let's try to do it ourselves
      begin
        date_match = parsed_ticket[:event_text].match(/(([a-z]+\.? [0-9]+,? [0-9]{4} [0-9]+)(:[0-9]{2})?(AM|PM|A|P))/i)

        date_str = nil
        if date_match[3].nil?
          date_str = date_match[2] + ":00" + date_match[4]
        else
          date_str = date_match[1]
        end
        self.parsed_event[:occurs_at] = DateTime.parse(date_str)
      rescue;end
    end
  end
  
  def parse_default
    ticket_data = pdf_text.match(/NUMB ?E ?R\n\n([^0-9]+) ([0-9a-z -]+).*?S ?E ?C ?T ?I ?O ?N\n?\n?([^\n]+).*?R ?O ?W\n\n([^\n]+).*?S ?E ?AT\n(\n([^\n ]{1,4})[^\n]{0,20}\n)?.*?\n([a-z0-9]+) [^\n]*\n\n(.*?)\n(.*?seat: ([^\n ]+))?.*?([0-9]{4} ?[0-9]{4} ?[0-9]{4} ?[0-9]{4})/im)
    if ticket_data
      self.parsed_ticket = {:purchaser => ticket_data[1],
                     :order_number => ticket_data[2],
                     :section => ticket_data[3].strip,
                     :row => ticket_data[4],
                     :seat => (ticket_data[5].nil? ? ticket_data[10] : ticket_data[6]),
                     :barcode_number => ticket_data[11].gsub(/ /, ''),
                     :viewed => false,
                     :event_text => ticket_data[8]}
      self.parsed_event = { :code => ticket_data[7] }
    end
  end
  
  def parse_mlb
    ticket_data = pdf_text.match(/([0-9]{4} ?[0-9]{4} ?[0-9]{4} ?[0-9]{4}).*?This.*?SECTION\n(.*?)\n.*?ROW\n(.*?)\n.*?SEAT\n(.*?)\n.*?Name: (.*?) Confirmation Number: ([^ ]* [^ ]*).*?Event Information:.*?\n([a-z0-9]+)(.*?)[0-9]{4} ?[0-9]{4} ?[0-9]{4} ?[0-9]{4}/im)
    if ticket_data
      self.parsed_ticket = {:purchaser => ticket_data[5],
                     :order_number => ticket_data[6],
                     :section => ticket_data[2],
                     :row => ticket_data[3],
                     :seat => ticket_data[4],
                     :barcode_number => ticket_data[1].gsub(/ /, ''),
                     :viewed => false,
                     :event_text => ticket_data[8]}
      self.parsed_event = { :code => ticket_data[7] }
    end
  end
  
  def parse_no_purchaser
    ticket_data = pdf_text.match(/NUMB ?E ?R\n?\n?.*?S ?E ?C ?T ?I ?O ?N\n?\n?([^\n]+).*?R ?O ?W\n\n([^\n]+).*?S ?E ?AT\n(\n([^\n ]{1,4})[^\n]{0,20}\n)?.*?\n([a-z0-9]+) [^\n]*\n\n(.*?)[a-z]?\5.*?\n(.*?seat: ([^\n ]+))?.*?([0-9]{4} ?[0-9]{4} ?[0-9]{4} ?[0-9]{4}).*?([0-9-]+)\n\n([0-9a-z]+)[\n ]*$/im)
    if ticket_data
      self.parsed_ticket = {:purchaser => '',
                     :order_number => ticket_data[10] + ' ' + ticket_data[11],
                     :section => ticket_data[1].strip,
                     :row => ticket_data[2],
                     :seat => (ticket_data[3].nil? ? ticket_data[8] : ticket_data[4]),
                     :barcode_number => ticket_data[9].gsub(/ /, ''),
                     :viewed => false,
                     :event_text => ticket_data[6].strip}
      self.parsed_event = { :code => ticket_data[5] }
    end
  end
  
  def parse_mlb_alt
    ticket_data = pdf_text.match(/([0-9]+).*?section\n([a-z0-9]+)\n\nrow\n([^\n]+)\n\nseat\n([^\n]+).*?\nevent\n([^\n]+).*?admittance to the event\. ([^ ]+?) section.*?\nname: (.*?) confirmation number: ([^ ]*)/im)
    if ticket_data
      self.parsed_ticket = {:purchaser => ticket_data[7],
                     :order_number => ticket_data[8],
                     :section => ticket_data[2],
                     :row => ticket_data[3],
                     :seat => ticket_data[4],
                     :barcode_number => ticket_data[1],
                     :viewed => false,
                     :event_text => ticket_data[5]}
      self.parsed_event = { :code => ticket_data[6] }
      self.parsed_venue_code = 'MLB'
    end
  end
  
  def parse_mlb_2007
    ticket_data = pdf_text.match(/print-at-home-tickets.*?TIXX.*?([0-9]+).*?gate:.*?seat:\n\n[^ ]+ [^ ]+ ([^ ]+) ([^ ]+) ([^ \n]+)\n\n(.*?)ticket price.*?transaction details\nname: (.*?) customer #/im)
    if ticket_data
      self.parsed_ticket = {:purchaser => ticket_data[6],
                     :section => ticket_data[2],
                     :row => ticket_data[3],
                     :seat => ticket_data[4],
                     :barcode_number => ticket_data[1],
                     :viewed => false,
                     :event_text => ticket_data[5].strip}
      self.parsed_event = { :code => 'MLB' }
      self.parsed_venue_code = 'MLB'
    end
  end
  
  def parse_exchange
    ticket_data = pdf_text.match(/section[^\n]*\n\n([^\n]*).*?row\n\n([^\n]*)\n\n([0-9]+-[0-9]+)\n\n([^ ]+).*?([0-9]{12}).*?([^\n]{25,150})\n/im)
    if ticket_data
      self.parsed_ticket = {:section => ticket_data[1], 
              :row => ticket_data[2], 
              :order_number => ticket_data[3],
              :seat => ticket_data[4],
              :barcode_number => ticket_data[5],
              :event_text => ticket_data[6]} 
    end
  end
  
  def parse_mlb_2008
    ticket_data = pdf_text.match(/([0-9]{4} ?[0-9]{4} ?[0-9]{4} ?[0-9]{4}).*?This.*?SECTION\n(.*?)\n.*?ROW\n(.*?)\n.*?SEAT\n(.*?)\n.*?NO REENTRY\.\n\nEVENT\n(.*?)\n.*?Name: (.*?) Confirmation Number: ([^ ]* [^ ]*).*?Event Information:.*?\n([a-z0-9]+)/im)
    if ticket_data
      self.parsed_ticket = {:purchaser => ticket_data[6],
                     :order_number => ticket_data[7],
                     :section => ticket_data[2],
                     :row => ticket_data[3],
                     :seat => ticket_data[4],
                     :barcode_number => ticket_data[1].gsub(/ /, ''),
                     :viewed => false,
                     :event_text => ticket_data[5]}
      self.parsed_event = { :code => ticket_data[8] }
    end
  end
end