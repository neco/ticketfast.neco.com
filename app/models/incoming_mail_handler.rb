require 'net/imap'
require 'timeout'

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
      puts "dealing with attachment" 
      
      # Make sure the MIME type indicates the part is a PDF attachment
      puts attachment.content_type
      next unless ['application/pdf', 'application/octet-stream'].include?(attachment.content_type) 
      
      puts "it is a pdf"
      
      filename = "tmp.pdf"
      filepath = tmp_dir + '/' + filename

      File.open(filepath, File::CREAT|File::TRUNC|File::WRONLY, 0644) do |f|
        f.write(attachment.read)
      end
      
      # Remove owner restrictions and decrypt the PDF
      `#{RAILS_ROOT}/bin/guapdf -y #{filepath}`
      if File.exists?( filepath.gsub(/\.pdf$/, '.decrypted.pdf') )
        `rm #{filepath}`
        filepath = filepath.gsub(/\.pdf$/, '.decrypted.pdf') 
      end
      
      # Split PDF into pages, filenames are page_01.pdf, page_02.pdf, etc 
      # Remove original pdf and a pdf doc descriptor that is created also
      `pdftk #{filepath} burst output #{tmp_dir}/page_%02d.pdf && rm doc_data.txt && rm #{filepath}`
      
      # Set up email attributes
      email_attrs = {:email_subject => email.subject, :email_from => email.from.first, :email_sent_at => email.date}
      
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
          ticket = Ticket.create({:unparsed => true}.merge(email_attrs))

          # Place the PDF ticket in the right place and clean up temporary pdftotext output file
          `mv #{page_filepath} #{pdf_dir}/#{ticket.id}.pdf && rm #{text_filepath}`
          
          ticket_count += 1 
          next
        end
        
        puts "we are good!!"
        
        ticket = ticket_parser.saved_ticket
        ticket.update_attributes(email_attrs)
        puts ticket.inspect
        if(ticket.errors.size > 0)
          puts "we have errors"
          ticket.errors.collect{|f,e| puts "#{f} #{e}" }
        end
        # Place the PDF ticket in the right place and clean up temporary pdftotext output file
        `mv #{page_filepath} #{pdf_dir}/#{ticket.id}.pdf && rm #{text_filepath}`
        ticket_count += 1
      end
    end if email.attachments
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
          #imap.authenticate('LOGIN', 'ticketfast@neco.com', '060381')
          imap.login('ticketfast@neco.com', '060381')
          imap.select('INBOX')
        }
        imap.search(['UNSEEN']).each do |message_id| 
          msg = imap.fetch(message_id,'RFC822')[0].attr['RFC822']
          begin
            num = IncomingMailHandler.receive(msg)
            ticket_count += num
            imap.store(message_id, '+FLAGS', [:Seen])
            imap.store(message_id, "+FLAGS", [:Flagged]) if num == 0
          rescue
            imap.store(message_id, "+FLAGS", [:Flagged])
            raise
          end
        end
      end
    rescue;raise;end
    ticket_count
  end
end