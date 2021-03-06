require 'tmclient'

class TicketRequestWorker < BackgrounDRb::MetaWorker
  set_worker_name :ticket_request_worker

  def create(args = nil)
    logger.debug "Creating ticket request worker"
  end

  def save_unseen_tickets(tm_account_id = nil)
    first_run = true

    while first_run || TmAccount.queued.size > 0
      @clients = {}

      if first_run
        if tm_account_id
          acct = TmAccount.find(tm_account_id)
          @clients[acct] = TMClient.new(acct.username, acct.password, logger)
        else
          TmAccount.enabled.each do |acct|
            @clients[acct] = TMClient.new(acct.username, acct.password, logger)
          end
        end

        first_run = false
      else
        TmAccount.queued.each do |acct|
          logger.debug "Running queued account #{acct.username}"
          @clients[acct] = TMClient.new(acct.username, acct.password, logger)
        end
      end

      threads = []

      ActiveRecord::Base.allow_concurrency = true

      @clients.each do |tmacct, tmclient|
        logger.debug "Updated status of #{tmacct.username} to queued."
        tmacct.update_attribute(:worker_status, 'queued')

        while threads.size >= 10
          sleep 5
          logger.debug "waiting on threads, we have #{threads.size}"

          threads.each do |t|
            unless t.alive?
              logger.debug 'killing a thread'
              t.join
              threads.delete(t)
              ActiveRecord::Base.verify_active_connections!
            end
          end
        end

        sleep(2)
        acct_id = tmacct.id

        threads << Thread.new(acct_id, tmclient) do |tm_acct_id, client|
          begin
            tm_acct = TmAccount.find(tm_acct_id)

            logger.debug "Updated status of #{tm_acct.username} to running."
            tm_acct.update_attributes(:worker_status => 'running', :worker_last_update_at => Time.now)

            unique_id = rand(10000)

            # do not grab tickets purchased before 9/1/08
            cutoff_date = Date.new(2008, 9, 1)

            logger.debug "working with #{tm_acct.inspect}, #{client.username}:#{client.password}"
            logger.debug "client order data #{client.order_data.inspect}"

            # This loop grabs a page of order history, and gets rid of tickets
            # we have already received
            #
            # If we have received tickets on the current page, it is assumed
            # that we don't need to look through older pages.
            #
            # If we see tickets ordered before the cutoff_date, we stop looking
            # further
            get_more_orders = true
            unfetched_order_numbers = Hash[*(tm_acct.tickets.unfetched.collect { |t| [t.order_number, t.tm_order_date] }.flatten)]

            while get_more_orders
              logger.debug "Getting a page of order history"
              client.get_order_history

              order_count = client.order_data.size
              oldest_order = client.order_data.collect { |h| Date.parse(h[:order_date]) }.sort.first

              raise "couldnt load any orders" if order_count == 0

              logger.debug "Order count: #{order_count}"
              logger.debug "Order data: #{client.order_data.inspect}"
              logger.debug "Unfetched order numbers: #{unfetched_order_numbers.size}"
              logger.debug "Unfetched orders: #{unfetched_order_numbers.inspect}"

              unfetched_order_numbers.delete_if do |num, date|
                logger.debug "MY NUM: #{num}"
                client.order_data.reject { |o| o[:order_number] != num }.size > 0
              end

              logger.debug "OD: #{client.order_data.inspect}"
              logger.debug "Unfetched order numbers after filter: #{unfetched_order_numbers.size}"

              client.order_data.delete_if do |order|
                (Ticket.fetched.find_by_order_number(order[:order_number]) or Date.parse(order[:order_date]) < cutoff_date) ? true : false
              end

              logger.debug "We have #{client.order_data.size} new orders"
              logger.debug "Newest is #{client.order_data.first[:order_date]} and oldest is #{client.order_data.last[:order_date]}" if client.order_data.size > 0

              oldest_unfetched = unfetched_order_numbers.collect { |k, v| v }.sort.first

              get_more_orders = false if (unfetched_order_numbers.size == 0 || oldest_unfetched > oldest_order || order_count < 10) && (client.order_data.size < order_count || order_count < 10)
            end

            if unfetched_order_numbers.size > 0
              unfetched_order_numbers.each do |num, date|
                tick = tm_acct.tickets.unfetched.find_by_order_number(num)
                tick.update_attribute(:unfetched_reason, 'No longer listed in order history.') if tick
              end
            end

            client.order_data.each do |order|
              Ticket.create(
                :order_number => order[:order_number],
                :unfetched => true,
                :tm_account_id => tm_acct.id,
                :tm_order_date => Date.parse(order[:order_date]),
                :tm_event_name => order[:event_name],
                :tm_venue_name => order[:venue_name],
                :tm_event_date => Date.parse(order[:event_date]) unless Ticket.find_by_order_number(order[:order_number])
              )

              old_tick = Ticket.find_by_order_number(order[:order_number])
              old_tick.update_attribute(:tm_account_id, tm_acct.id) if old_tick
            end

            client.order_data.size.times do
              begin
                logger.debug "Working on saving a ticket"

                filepath = "#{Settings.tmp_dir}/tmclient_#{unique_id}_pdf.pdf"

                order = client.order_data.first

                begin
                  client.save_ticket(filepath)
                rescue Exception => e
                  Ticket.unfetched.find_by_order_number(order[:order_number]).update_attribute(:unfetched_reason, e.to_s)
                  next
                end

                logger.debug "Ticket saved, decrypting"

                # Remove owner restrictions and decrypt the PDF
                `#{Rails.root}/bin/guapdf -y #{filepath}`
                if File.exists?( filepath.gsub(/\.pdf$/, '.decrypted.pdf') )
                  `rm #{filepath}`
                  filepath = filepath.gsub(/\.pdf$/, '.decrypted.pdf')
                end

                logger.debug "Decrypted, bursting pages"

                # Split PDF into pages, filenames are page_01.pdf, page_02.pdf,
                # etc. Remove original PDF and a PDF doc descriptor that is
                # created also
                `pdftk #{filepath} burst output #{Settings.tmp_dir}/page_#{unique_id}_%02d.pdf && rm doc_data.txt && rm #{filepath}`

                logger.debug "Burst! going through pages"

                # Loop through each PDF page, parse text, create Ticket, rename
                # to {ticket.id}.pdf and place in pdfs directory
                Dir.glob("#{Settings.tmp_dir}/page_#{unique_id}_*pdf").each do |page_filepath|
                  logger.debug "In a page, converting to text"
                  `pdftotext #{page_filepath}`
                  text_filepath = page_filepath.gsub /pdf$/, 'txt'
                  pdf_text = File.read(text_filepath)

                  logger.debug "Converted, running the ticket parser"

                  # Attempt to parse the text-converted PDF
                  ticket_parser = TicketParser.new(pdf_text)
                  ticket_parser.parse_and_save!

                  ticket = nil

                  # If parsing failed, save the PDF and add it to the queue
                  unless ticket_parser.parsed?
                    ticket = Ticket.create({:unparsed => true})
                    logger.debug 'Could not parse ticket, saving unparsed'
                  end

                  ticket ||= ticket_parser.saved_ticket

                  tickets_to_destroy = tm_acct.tickets.unfetched.all(:conditions => {:order_number => order[:order_number]})
                  logger.debug "trying to get rid of #{tickets_to_destroy.inspect}"
                  tickets_to_destroy.each { |t| t.destroy }

                  ticket.tm_account_id = tm_acct.id
                  ticket.order_number = order[:order_number]
                  ticket.tm_order_date = order[:order_date]
                  ticket.tm_event_name = order[:event_name]
                  ticket.tm_venue_name = order[:venue_name]
                  ticket.tm_event_date = order[:event_date]
                  ticket.save
                  logger.debug ticket.inspect

                  # Place the PDF ticket in the right place and clean up
                  # temporary pdftotext output file
                  `mv #{page_filepath} #{Settings.pdf_dir}/#{ticket.id}.pdf && rm #{text_filepath}`
                end
              rescue Exception => e
                logger.debug "IN LOOP EXCEPTION! #{e.inspect}"
              end
            end

            logger.debug "All done!"
          rescue Exception => e
            logger.debug "EXCEPTION! #{e.inspect}"
          end

          tm_acct.update_attributes(
            :worker_status => 'stopped',
            :worker_last_update_at => Time.now,
            :worker_job_target => nil
          )

          FetcherJob.register_client_done(client.username)
        end
      end

      threads.each do |t|
        logger.debug 'final join: joining thread'
        t.join
        ActiveRecord::Base.verify_active_connections!
      end

      logger.debug "Telling the job queue worker that we are done"
      logger.debug "Told the job queue worker we are done"
    end
  end
end
