class TicketsMailer < ActionMailer::Base
  def attached_pdf(recipient, filepath, subject="TicketFast tickets attached")
    @recipients = recipient
    @bcc = 'cmiller@neco.com'
    @subject = subject
    @from = 'NECO <ticketfast@neco.com>'

    part :content_type => 'text/plain',
         :body => render_message('attached_pdf', body)

    attachment "application/pdf" do |a|
      a.body = File.read(filepath)
      a.filename = 'tickets.pdf'
    end
  end

  def exchange data, filepath
    @recipients = "ticketfast@neco.com"
    @subject = %(Exchange | #{data[:event_text]} | Section: #{data[:section]}, Row: #{data[:row]}, Seat: #{data[:seat]})
    @from = "NECO <ticketfast@neco.com>"

    part :content_type => 'text/plain',
         :body => render_message('exchange', body)

    attachment 'application/pdf' do |a|
      a.body = File.read(filepath)
      a.filename = 'tickets.pdf'
    end
  end
end
