require 'tmclient'
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

  desc "Grab three tickets we don't have and process them"
  task :tmclient_test => :environment do
    client = TMClient.new
        
    # filter out tickets we already have
    while client.order_data.size < 3
      puts "GETTING ORDER HISTORY"
      client.get_order_history
      client.order_data.delete_if {|order| Ticket.find_by_order_number(order[:order_number]) ? true : false}
    end
    
    # factor this out where possible
    tmp_dir = "#{RAILS_ROOT}/#{Setting['tmp_dir']}"
    pdf_dir = "#{RAILS_ROOT}/#{Setting['pdf_dir']}"
      
    3.times do 
      filepath = "#{tmp_dir}/tmclient_pdf.pdf"
      client.save_ticket(filepath)
    
      # Remove owner restrictions and decrypt the PDF
      `#{RAILS_ROOT}/bin/guapdf -y #{filepath}`
      if File.exists?( filepath.gsub(/\.pdf$/, '.decrypted.pdf') )
        `rm #{filepath}`
        filepath = filepath.gsub(/\.pdf$/, '.decrypted.pdf') 
      end
    
      # Split PDF into pages, filenames are page_01.pdf, page_02.pdf, etc 
      # Remove original pdf and a pdf doc descriptor that is created also
      `pdftk #{filepath} burst output #{tmp_dir}/page_%02d.pdf && rm doc_data.txt && rm #{filepath}`
    
      # Loop through each PDF page, parse text, create Ticket, rename to {ticket.id}.pdf and place in pdfs directory
      Dir.glob("#{tmp_dir}/page_*pdf").each do |page_filepath|
        puts 'doing a page'
        `pdftotext #{page_filepath}`
        text_filepath = page_filepath.gsub /pdf$/, 'txt'
        pdf_text = File.read(text_filepath)
        puts 'trying to parse!'
        # Attempt to parse the text-converted PDF
        ticket_parser = TicketParser.new(pdf_text)
        ticket_parser.parse_and_save!
      
        # If parsing failed, save the PDF and add it to the queue
        unless ticket_parser.parsed?
          puts "no luck"
          ticket = Ticket.create({:unparsed => true})

          # Place the PDF ticket in the right place and clean up temporary pdftotext output file
          `mv #{page_filepath} #{pdf_dir}/#{ticket.id}.pdf && rm #{text_filepath}`
        
          next
        end
      
        puts "we are good!!"
      
        ticket = ticket_parser.saved_ticket
        puts ticket.inspect
        # Place the PDF ticket in the right place and clean up temporary pdftotext output file
        `mv #{page_filepath} #{pdf_dir}/#{ticket.id}.pdf && rm #{text_filepath}`
      end
    end
  end
end