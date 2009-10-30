require 'net/imap'
require 'timeout'

class IncomingMailHandler < ActionMailer::Base
  def receive(email)
    ticket_count = 0

    # Fix the inconvenient fact that Net::IMAP ignores message/* MIME types.
    email.parts.each do |part|
      next unless part.content_type == 'message/rfc822'
      IncomingMailHandler.receive(part.body)
    end

    if email.attachments
      email.attachments.each do |attachment|
        # Ensure that the MIME type indicates that the part is a PDF attachment.
        next unless %w(application/pdf application/octet-stream).include?(attachment.content_type)

        filepath = File.join(Settings.tmp_dir, 'tmp.pdf')
        File.open(filepath, 'w', 0644) { |f| f.write(attachment.read) }

        # Remove owner restrictions and decrypt the PDF.
        `#{Rails.root}/bin/guapdf -y #{filepath}`

        if File.exists?(filepath.gsub(/\.pdf$/, '.decrypted.pdf'))
          File.delete(filepath)
          filepath = filepath.gsub(/\.pdf$/, '.decrypted.pdf')
        end

        # Split PDF into pages, filenames are page_01.pdf, page_02.pdf, etc.
        # Remove original PDF and a PDF doc descriptor that is created also
        `pdftk #{filepath} burst output #{Settings.tmp_dir}/page_%02d.pdf`
        File.delete('doc_data.txt', filepath)

        email_attrs = {
          :email_subject => email.subject,
          :email_from => email.from.first,
          :email_sent_at => email.date
        }

        # Loop through each PDF page, parse text, create Ticket, rename to
        # {ticket.id}.pdf and place into the pdfs directory.
        Dir.glob("#{Settings.tmp_dir}/page_*pdf").each do |page_filepath|
          `pdftotext #{page_filepath}`
          text_filepath = page_filepath.gsub(/\.pdf$/, '.txt')
          pdf_text = File.read(text_filepath)

          # Attempt to parse the text-converted PDF
          ticket_parser = TicketParser.new(pdf_text)
          ticket_parser.parse_and_save!

          if ticket_parser.parsed?
            ticket = ticket_parser.saved_ticket
            ticket.update_attributes(email_attrs)
          else
            # If parsing failed, save the PDF and add it to the queue
            ticket = Ticket.create({ :unparsed => true }.merge(email_attrs))
          end

          # Place the PDF ticket in the right place and remove temporary file.
          ticket_key = File.join('pdfs', "#{ticket.id}.pdf")
          BUCKET.put(ticket_key, File.read(page_filepath), 'public-read')
          File.delete(page_filepath, text_filepath)

          ticket_count += 1
        end
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
        sleep 20 if message_count < 0

        message_count = new_message_count
        imap = nil

        Timeout.timeout(10) do
          imap = Net::IMAP.new('imap.gmail.com', 993, true)
          imap.login('ticketfast@neco.com', '060381')
          imap.select('INBOX')
        end

        imap.search(['UNSEEN']).each do |message_id|
          msg = imap.fetch(message_id, 'RFC822')[0].attr['RFC822']

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
    rescue
      raise
    end

    ticket_count
  end
end
