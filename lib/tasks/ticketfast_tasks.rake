namespace :ticketfast do
  desc 'Process and import new mail'
  task :process_mail => :environment do
    IncomingMailHandler.process_new_mail
  end
  
  desc 'Run tm fetcher on all enabled accounts'
  task :fetch_tm => :environment do
    MiddleMan.worker(:ticket_request_worker).async_save_unseen_tickets
    puts "Running worker"
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

      if ticket_parser.saved_ticket && !ticket_parser.saved_ticket.errors[:barcode_number].nil?
        ticket.destroy
        puts "Destroyed ticket because it is a duplicate."
      else
        parsed += 1 if ticket_parser.parsed?
      end

      puts "#{ticket_parser.parsed? ? 'Parsed' : 'Parse failed'} - #{i} of #{total}"
    end

    puts "Parsed #{parsed} of #{total}"
  end
end
