require 'net/imap'
require 'timeout'

module TMail
  class Mail
    def attachments
      if multipart?
        parts.collect { |part|
          if part.multipart?
            part.attachments
          elsif attachment?(part)
            content   = part.body # unquoted automatically by TMail#body
            file_name = (part['content-location'] &&
                          part['content-location'].body) ||
                        part.sub_header("content-type", "name") ||
                        part.sub_header("content-disposition", "filename")
         
            next if file_name.blank? || content.blank?
         
            attachment = Attachment.new(content)
            attachment.original_filename = file_name.strip
            attachment.content_type = part.content_type
            attachment
          end
        }.flatten.compact
      end     
    end
  end
end

class IncomingMailHandler < ActionMailer::Base
  def receive(email)
    ticket_count = 0
    tmp_dir = "#{RAILS_ROOT}/#{Setting['tmp_dir']}"
    pdf_dir = "#{RAILS_ROOT}/#{Setting['pdf_dir']}"

    # Fix the inconvenient fact that Net::IMAP ignores message/* MIME types
    email.parts.each do |part|
      next unless part.content_type == 'message/rfc822'
      IncomingMailHandler.receive part.body
    end    
    
    email.attachments.each do |attachment|
      # Make sure the MIME type indicates the part is a PDF attachment
      puts "Checking MIMETYPE - #{attachment.content_type}"
      next unless attachment.content_type == 'application/pdf'
      filename = "tmp.pdf"
      filepath = tmp_dir + '/' + filename
      puts "Writing to #{filepath}"
      File.open(filepath, File::CREAT|File::TRUNC|File::WRONLY, 0644) do |f|
        f.write(attachment.read)
      end
      # Remove owner restrictions and decrypt the PDF
      puts "Decrypting PDF"
      `guapdf -y #{filepath}`
      if File.exists?( filepath.gsub(/\.pdf$/, '.decrypted.pdf') )
        `rm #{filepath}`
        filepath = filepath.gsub(/\.pdf$/, '.decrypted.pdf') 
      end
      # Split PDF into pages, filenames are page_01.pdf, page_02.pdf, etc 
      # Remove original pdf and a pdf doc descriptor that is created also
      puts "Bursting pages of PDF"
      `pdftk #{filepath} burst output #{tmp_dir}/page_%02d.pdf && rm doc_data.txt && rm #{filepath}`
      
      # Loop through each PDF page, parse text, create Ticket, rename to {ticket.id}.pdf
      Dir.glob("#{tmp_dir}/page_*pdf").each do |page_filepath|
        puts "Converting PDF to text on #{page_filepath}"
        `pdftotext #{page_filepath}`
        text_filepath = page_filepath.gsub /pdf$/, 'txt'
        pdf_text = File.read(text_filepath)
        venue_code = nil
        ticket_data = pdf_text.match(/NUMB ?E ?R\n\n([^0-9]+) ([0-9a-z -]+).*?S ?E ?C ?T ?I ?O ?N\n?\n?([^\n]+).*?R ?O ?W\n\n([^\n]+).*?S ?E ?AT\n(\n([^\n ]{1,4})[^\n]{0,20}\n)?.*?\n([a-z0-9]+) [^\n]*\n\n(.*?)\n(.*?seat: ([^\n ]+))?.*?([0-9]{4} ?[0-9]{4} ?[0-9]{4} ?[0-9]{4})/im)
        ticket_hash, event_hash = nil
        if ticket_data
          puts "Parsed normal ticket with event code #{ticket_data[7]}"
          ticket_hash = {:purchaser => ticket_data[1],
                         :order_number => ticket_data[2],
                         :section => ticket_data[3].strip,
                         :row => ticket_data[4],
                         :seat => (ticket_data[5].nil? ? ticket_data[10] : ticket_data[6]),
                         :barcode_number => ticket_data[11].gsub(/ /, ''),
                         :viewed => false,
                         :event_text => ticket_data[8]}
          event_hash = { :code => ticket_data[7] }
        else
          puts "Parsing MLB ticket"
          ticket_data = pdf_text.match(/([0-9]{4} ?[0-9]{4} ?[0-9]{4} ?[0-9]{4}).*?This.*?SECTION\n(.*?)\n.*?ROW\n(.*?)\n.*?SEAT\n(.*?)\n.*?Name: (.*?) Confirmation Number: ([^ ]* [^ ]*).*?Event Information:.*?\n([a-z0-9]+)(.*?)[0-9]{4} ?[0-9]{4} ?[0-9]{4} ?[0-9]{4}/im)
          if ticket_data
            ticket_hash = {:purchaser => ticket_data[5],
                           :order_number => ticket_data[6],
                           :section => ticket_data[2],
                           :row => ticket_data[3],
                           :seat => ticket_data[4],
                           :barcode_number => ticket_data[1].gsub(/ /, ''),
                           :viewed => false,
                           :event_text => ticket_data[8]}
            event_hash = { :code => ticket_data[7] }
          end
        end
        unless ticket_data
          puts "Trying the no purchaser format"
          ticket_data = pdf_text.match(/NUMB ?E ?R\n?\n?.*?S ?E ?C ?T ?I ?O ?N\n?\n?([^\n]+).*?R ?O ?W\n\n([^\n]+).*?S ?E ?AT\n(\n([^\n ]{1,4})[^\n]{0,20}\n)?.*?\n([a-z0-9]+) [^\n]*\n\n(.*?)[a-z]?\5.*?\n(.*?seat: ([^\n ]+))?.*?([0-9]{4} ?[0-9]{4} ?[0-9]{4} ?[0-9]{4}).*?([0-9-]+)\n\n([0-9a-z]+)[\n ]*$/im)
          ticket_hash, event_hash = nil
          if ticket_data
            puts "Parsed normal ticket with event code #{ticket_data[5]}"
            ticket_hash = {:purchaser => '',
                           :order_number => ticket_data[10] + ' ' + ticket_data[11],
                           :section => ticket_data[1].strip,
                           :row => ticket_data[2],
                           :seat => (ticket_data[3].nil? ? ticket_data[8] : ticket_data[4]),
                           :barcode_number => ticket_data[9].gsub(/ /, ''),
                           :viewed => false,
                           :event_text => ticket_data[6].strip}
            event_hash = { :code => ticket_data[5] }

          end
        end
        unless ticket_data
          puts "Trying another MLB ticket format"
          ticket_data = pdf_text.match(/([0-9]+).*?section\n([a-z0-9]+)\n\nrow\n([^\n]+)\n\nseat\n([^\n]+).*?\nevent\n([^\n]+).*?admittance to the event\. ([^ ]+?) section.*?\nname: (.*?) confirmation number: ([^ ]*)/im)
          if ticket_data
            puts "Parsed ticket with event code #{ticket_data[6]}"
            ticket_hash = {:purchaser => ticket_data[7],
                           :order_number => ticket_data[8],
                           :section => ticket_data[2],
                           :row => ticket_data[3],
                           :seat => ticket_data[4],
                           :barcode_number => ticket_data[1],
                           :viewed => false,
                           :event_text => ticket_data[5]}
            event_hash = { :code => ticket_data[6] }
            venue_code = 'MLB'
          end
        end
        unless ticket_data
          puts "Trying 2007 MLB format"
          ticket_data = pdf_text.match(/print-at-home-tickets.*?TIXX.*?([0-9]+).*?gate:.*?seat:\n\n[^ ]+ [^ ]+ ([^ ]+) ([^ ]+) ([^ \n]+)\n\n(.*?)ticket price.*?transaction details\nname: (.*?) customer #/im)
          ticket_hash, event_hash = nil
          if ticket_data
            puts "Parsed ticket with event code #{ticket_data[5]}"
            ticket_hash = {:purchaser => ticket_data[6],
                           :section => ticket_data[2],
                           :row => ticket_data[3],
                           :seat => ticket_data[4],
                           :barcode_number => ticket_data[1],
                           :viewed => false,
                           :event_text => ticket_data[5].strip}
            event_hash = { :code => 'MLB' }
            venue_code = 'MLB'
          end
        end
        unless ticket_data
          puts "Looking for exchange tickets"
          # try and match one format..
          ticket_data = pdf_text.match(/section[^\n]*\n\n([^\n]*).*?row\n\n([^\n]*)\n\n([0-9]+-[0-9]+)\n\n([^ ]+).*?([0-9]{12}).*?([^\n]{25,150})\n/im)
          if ticket_data
            puts "matched"
            ticket_hash = {:section => ticket_data[1], 
                    :row => ticket_data[2], 
                    :order_number => ticket_data[3],
                    :seat => ticket_data[4],
                    :barcode_number => ticket_data[5],
                    :event_text => ticket_data[6]} 
            event_hash = {}
          end
        end
         #   puts TicketsMailer.deliver_exchange data, page_filepath
  #          puts "forwarded back to ticketfast@neco"
  #          ticket_count += 1
  #          `rm #{text_filepath} && rm #{page_filepath}`
  #        end
  #      end
        unless ticket_data
          puts "Cannot parse! Saving PDF and adding to queue"
          ticket = Ticket.create 
          puts "Created empty ticket (ID #{ticket.id})"
          # Place the PDF ticket in the right place and clean up temporary pdftotext output file
          `mv #{page_filepath} #{pdf_dir}/#{ticket.id}.pdf && rm #{text_filepath}`
          ticket_count += 1 
          next
        end
        puts "Ticket hash: " + ticket_hash.inspect
        # Attempt to parse a datetime out of event text
        begin
          event_hash[:occurs_at] = DateTime.parse ticket_hash[:event_text]
        rescue
          begin
            date_match = ticket_hash[:event_text].match(/(([a-z]+\.? [0-9]+,? [0-9]{4} [0-9]+)(:[0-9]{2})?(AM|PM|A|P))/i)
            puts "Date parse failure, attempting with #{date_match[1]}"
            date_str = nil
            if date_match[3].nil?
              date_str = date_match[2] + ":00" + date_match[4]
            else
              date_str = date_match[1]
            end
            event_hash[:occurs_at] = DateTime.parse date_str
          rescue;end
        end
        venue_code = event_hash[:code].match(/^[^0-9]+/)[0] unless venue_code or !event_hash[:code]
        event = Event.find_all_by_code event_hash[:code]
        # Create event if the event code does not exist yet
        if event.size == 0 and event_hash[:code]
          event = Event.create event_hash
          puts "Created event #{event.code} (ID #{event.id})"
        else
          event = event.first
        end
        if event
          ticket = event.tickets.create ticket_hash
          event.set_venue! venue_code unless event.venue
        else
          ticket = Ticket.create ticket_hash
        end
        puts "Created ticket with barcode #{ticket.barcode_number} (ID #{ticket.id})"
        # Place the PDF ticket in the right place and clean up temporary pdftotext output file
        `mv #{page_filepath} #{pdf_dir}/#{ticket.id}.pdf && rm #{text_filepath}`
        ticket_count += 1 unless ticket.new_record?
      end
    end
    ticket_count
  end
  
  def self.process_new_mail
    ticket_count = 0
    message_count = -1
    new_message_count = 0
    begin
    while message_count < new_message_count
      unless message_count < 0
        puts "Waiting 20 seconds to reconnect..." 
        sleep 20
      end
      message_count = new_message_count
      puts "Connecting to host"
      imap = nil
      Timeout.timeout(10) {
        imap = Net::IMAP.new('imap.neco.com')
#imap = Net::IMAP.new('enoch.uoregon.edu')   
        #imap.authenticate('LOGIN', 'ticketfast@neco.com', '060381')
        imap.login('ticketfast@neco.com', '060381')
#imap = Net::IMAP.new('mail.neco.com')
#imap.authenticate('LOGIN', 'unprocessedtf@neco.com', '060381')
#imap.login('unprocessedtf@neco.com', '060381')
#imap.authenticate('LOGIN', 'ticketfast', 'tfneco')   
     
        imap.select('INBOX')
      }
      puts "selected inbox"
      imap.search(['UNSEEN']).each do |message_id| #should be NEW not ALL
        puts "Fetching message #{new_message_count += 1}"
        msg = imap.fetch(message_id,'RFC822')[0].attr['RFC822']
        begin
          puts "Trying to receive the message"
          num = IncomingMailHandler.receive(msg)
          ticket_count += num
          imap.store(message_id, '+FLAGS', [:Seen])
          if num > 0
           #imap.store(message_id, "+FLAGS", [:Flagged])
          end
        rescue;end
      end
      break
    end
    rescue;end
    ticket_count
  end

  
end
