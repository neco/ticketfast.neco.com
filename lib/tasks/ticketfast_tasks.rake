namespace :ticketfast do
  desc 'Process and import new mail'
  task :process_mail => :environment do
    IncomingMailHandler.process_new_mail
  end
  
  desc 'Reparse all unparsed tickets'
  task :reparse_all => :environment do
    total = Ticket.unparsed.count
    i = 0
    parsed = 0
    Ticket.unparsed.each do |ticket|
      i += 1
      ticket_parser = TicketParser.new(ticket)
      ticket_parser.parse_and_save!
      if ticket_parser.saved_ticket and !ticket_parser.saved_ticket.errors[:barcode_number].nil?
        ticket.destroy
        puts "Destroyed ticket because it is a duplicate."
      else
        parsed += 1 if(ticket_parser.parsed?)
      end
      puts "#{ticket_parser.parsed? ? 'Parsed' : 'Parse failed'} - #{i} of #{total}"
    end
    puts "Parsed #{parsed} of #{total}"
  end
end