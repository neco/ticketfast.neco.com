require 'tmclient'
class TicketRequestWorker < BackgrounDRb::MetaWorker
  set_worker_name :ticket_request_worker
  
  def create(args = nil)
    logger.debug 'setting up request worker'
    @accounts = [
      {:username => 'dgainor99@gmail.com', :password => '060381'},
      {:username => 'sgainor99@gmail.com', :password => '060381'},
      {:username => 'bedrock95@yahoo.com', :password => 'mazzylama74'}
    ]
    logger.debug 'cool!'
  end
  
  def simple_test
    t1 = Thread.new {
      client1 = TMClient.new('dgainor99@gmail.com', '060381', logger)
      client1.get_order_history
    }
    t2 = Thread.new {
      client2 = TMClient.new('sgainor99@gmail.com', '060381', logger)
      client2.get_order_history
    }
    t1.join
    t2.join
  end
  
  def save_unseen_tickets
    @clients = {}
    @accounts.each do |acct|
      @clients[acct[:username]] = TMClient.new(acct[:username], acct[:password], logger)
    end
    threads = []
    @clients.each do |tmusername, tmclient|
      threads << Thread.new(tmusername, tmclient) do |username, client| 
        begin
          unique_id = rand(10000)
      
          # do not grab tickets purchased before 9/1/08
          cutoff_date = Date.new(2008,9,1)
    
          logger.debug "working with #{username}, #{client.inspect}"
          logger.debug "client order data #{client.order_data.inspect}"
    
          # This loop grabs a page of order history, and gets rid of tickets we have already received
          #
          # If we have received tickets on the current page, it is assumed that we don't need to look 
          # through older pages.
          #
          # If we see tickets ordered before the cutoff_date, we stop looking further
          get_more_orders = true
          while get_more_orders
            logger.debug "Getting a page of order history"
            client.get_order_history
     
            order_count = client.order_data.size
            client.order_data.delete_if {|order| Ticket.find_by_order_number(order[:order_number]) ? true : false}
            logger.debug "We have #{client.order_data.size} new orders"
            logger.debug "Newest is #{client.order_data.first[:order_date]} and oldest is #{client.order_data.last[:order_date]}" if client.order_data.size > 0
      
            get_more_orders = false if client.order_data.size < order_count or Date.parse(client.order_data.last[:order_date]) < cutoff_date
          end
    
          client.order_data.each do |order|
            Ticket.create :order_number => order[:order_number], :unfetched => true, :tm_account => username
          end

          # factor this out where possible
          tmp_dir = "#{RAILS_ROOT}/#{Setting['tmp_dir']}"
          pdf_dir = "#{RAILS_ROOT}/#{Setting['pdf_dir']}"

          client.order_data.size.times do 
            begin
              logger.debug "Working on saving a ticket"
      
              filepath = "#{tmp_dir}/tmclient#_#{unique_id}_pdf.pdf"
              client.save_ticket(filepath)

              # Remove owner restrictions and decrypt the PDF
              `#{RAILS_ROOT}/bin/guapdf -y #{filepath}`
              if File.exists?( filepath.gsub(/\.pdf$/, '.decrypted.pdf') )
                `rm #{filepath}`
                filepath = filepath.gsub(/\.pdf$/, '.decrypted.pdf') 
              end

              # Split PDF into pages, filenames are page_01.pdf, page_02.pdf, etc 
              # Remove original pdf and a pdf doc descriptor that is created also
              `pdftk #{filepath} burst output #{tmp_dir}/page_#{unique_id}_%02d.pdf && rm doc_data.txt && rm #{filepath}`

              # Loop through each PDF page, parse text, create Ticket, rename to {ticket.id}.pdf and place in pdfs directory
              Dir.glob("#{tmp_dir}/page_#{unique_id}_*pdf").each do |page_filepath|
                `pdftotext #{page_filepath}`
                text_filepath = page_filepath.gsub /pdf$/, 'txt'
                pdf_text = File.read(text_filepath)

                # Attempt to parse the text-converted PDF
                ticket_parser = TicketParser.new(pdf_text)
                ticket_parser.parse_and_save!

                # If parsing failed, save the PDF and add it to the queue
                unless ticket_parser.parsed?
                  ticket = Ticket.create({:unparsed => true})
                  logger.debug 'Could not parse ticket, saving unparsed'
                  # Place the PDF ticket in the right place and clean up temporary pdftotext output file
                  `mv #{page_filepath} #{pdf_dir}/#{ticket.id}.pdf && rm #{text_filepath}`

                  next
                end

                ticket = ticket_parser.saved_ticket
                ticket.tm_account = username
                ticket.save
                logger.debug ticket.inspect
        
                Ticket.find(:first, :conditions => {:order_number => ticket.order_number, :unfetched => true}).destroy
        
                # Place the PDF ticket in the right place and clean up temporary pdftotext output file
                `mv #{page_filepath} #{pdf_dir}/#{ticket.id}.pdf && rm #{text_filepath}`
              end
            end
          end
          logger.debug "All done!"
        rescue;end
      end
    end
 
    threads.each do |t|  logger.debug 'joining thread'; t.join; end

  end
end