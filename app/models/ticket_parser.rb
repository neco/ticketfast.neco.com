class TicketParser
  attr_accessor :ticket, :event, :venue_code, :pdf_text
  
  def initialize(pdf_text)
    self.pdf_text = pdf_text
  end
  
  def parse!
    parsed_data = nil
    %w(default mlb no_purchaser mlb_alt mlb_2007 exchange).each do |format|
      puts "trying #{format}!!"
      parsed_data = send('parse_' + format)
      break if parsed?
    end
    puts "helllllllo"
    self.venue_code = event_hash[:code].match(/^[^0-9]+/)[0] unless venue_code or !event_hash[:code]
  end
  
  def parsed?
    ticket && event
  end

private
  
  def parse_default
    ticket_data = pdf_text.match(/NUMB ?E ?R\n\n([^0-9]+) ([0-9a-z -]+).*?S ?E ?C ?T ?I ?O ?N\n?\n?([^\n]+).*?R ?O ?W\n\n([^\n]+).*?S ?E ?AT\n(\n([^\n ]{1,4})[^\n]{0,20}\n)?.*?\n([a-z0-9]+) [^\n]*\n\n(.*?)\n(.*?seat: ([^\n ]+))?.*?([0-9]{4} ?[0-9]{4} ?[0-9]{4} ?[0-9]{4})/im)
    if ticket_data
      self.ticket = {:purchaser => ticket_data[1],
                     :order_number => ticket_data[2],
                     :section => ticket_data[3].strip,
                     :row => ticket_data[4],
                     :seat => (ticket_data[5].nil? ? ticket_data[10] : ticket_data[6]),
                     :barcode_number => ticket_data[11].gsub(/ /, ''),
                     :viewed => false,
                     :event_text => ticket_data[8]}
      self.event = { :code => ticket_data[7] }
    end
  end
  
  def parse_mlb
    ticket_data = pdf_text.match(/([0-9]{4} ?[0-9]{4} ?[0-9]{4} ?[0-9]{4}).*?This.*?SECTION\n(.*?)\n.*?ROW\n(.*?)\n.*?SEAT\n(.*?)\n.*?Name: (.*?) Confirmation Number: ([^ ]* [^ ]*).*?Event Information:.*?\n([a-z0-9]+)(.*?)[0-9]{4} ?[0-9]{4} ?[0-9]{4} ?[0-9]{4}/im)
    if ticket_data
      self.ticket = {:purchaser => ticket_data[5],
                     :order_number => ticket_data[6],
                     :section => ticket_data[2],
                     :row => ticket_data[3],
                     :seat => ticket_data[4],
                     :barcode_number => ticket_data[1].gsub(/ /, ''),
                     :viewed => false,
                     :event_text => ticket_data[8]}
      self.event = { :code => ticket_data[7] }
    end
  end
  
  def parse_no_purchaser
    ticket_data = pdf_text.match(/NUMB ?E ?R\n?\n?.*?S ?E ?C ?T ?I ?O ?N\n?\n?([^\n]+).*?R ?O ?W\n\n([^\n]+).*?S ?E ?AT\n(\n([^\n ]{1,4})[^\n]{0,20}\n)?.*?\n([a-z0-9]+) [^\n]*\n\n(.*?)[a-z]?\5.*?\n(.*?seat: ([^\n ]+))?.*?([0-9]{4} ?[0-9]{4} ?[0-9]{4} ?[0-9]{4}).*?([0-9-]+)\n\n([0-9a-z]+)[\n ]*$/im)
    if ticket_data
      self.ticket = {:purchaser => '',
                     :order_number => ticket_data[10] + ' ' + ticket_data[11],
                     :section => ticket_data[1].strip,
                     :row => ticket_data[2],
                     :seat => (ticket_data[3].nil? ? ticket_data[8] : ticket_data[4]),
                     :barcode_number => ticket_data[9].gsub(/ /, ''),
                     :viewed => false,
                     :event_text => ticket_data[6].strip}
      self.event = { :code => ticket_data[5] }
    end
  end
  
  def parse_mlb_alt
    ticket_data = pdf_text.match(/([0-9]+).*?section\n([a-z0-9]+)\n\nrow\n([^\n]+)\n\nseat\n([^\n]+).*?\nevent\n([^\n]+).*?admittance to the event\. ([^ ]+?) section.*?\nname: (.*?) confirmation number: ([^ ]*)/im)
    if ticket_data
      self.ticket = {:purchaser => ticket_data[7],
                     :order_number => ticket_data[8],
                     :section => ticket_data[2],
                     :row => ticket_data[3],
                     :seat => ticket_data[4],
                     :barcode_number => ticket_data[1],
                     :viewed => false,
                     :event_text => ticket_data[5]}
      self.event = { :code => ticket_data[6] }
      self.venue_code = 'MLB'
    end
  end
  
  def parse_mlb_2007
    ticket_data = pdf_text.match(/print-at-home-tickets.*?TIXX.*?([0-9]+).*?gate:.*?seat:\n\n[^ ]+ [^ ]+ ([^ ]+) ([^ ]+) ([^ \n]+)\n\n(.*?)ticket price.*?transaction details\nname: (.*?) customer #/im)
    if ticket_data
      self.ticket = {:purchaser => ticket_data[6],
                     :section => ticket_data[2],
                     :row => ticket_data[3],
                     :seat => ticket_data[4],
                     :barcode_number => ticket_data[1],
                     :viewed => false,
                     :event_text => ticket_data[5].strip}
      self.event = { :code => 'MLB' }
      self.venue_code = 'MLB'
    end
  end
  
  def parse_exchange
    ticket_data = pdf_text.match(/section[^\n]*\n\n([^\n]*).*?row\n\n([^\n]*)\n\n([0-9]+-[0-9]+)\n\n([^ ]+).*?([0-9]{12}).*?([^\n]{25,150})\n/im)
    if ticket_data
      self.ticket = {:section => ticket_data[1], 
              :row => ticket_data[2], 
              :order_number => ticket_data[3],
              :seat => ticket_data[4],
              :barcode_number => ticket_data[5],
              :event_text => ticket_data[6]} 
    end
  end
end