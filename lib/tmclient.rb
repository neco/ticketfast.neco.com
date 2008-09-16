require 'rubygems'
require 'hpricot'
require 'cgi'
require 'timeout'

class TMClient
  attr_accessor :form_data, :doc, :src, :order_data, :pages_fetched, :cookies, :logger, :job_target, :username, :password
  
  def initialize(username='dgainor99@gmail.com', password='060381', logger=nil)
    self.username, self.password = username, password
    self.logger = logger
    self.pages_fetched = 0
    self.order_data = []
  end
  
  def debug msg
    out = "[TMCLIENT #{self.username} #{Time.now.strftime("%H:%M:%S")}] #{msg}"
    if logger
      logger.debug(out)
    else
      puts(out)
    end
  end
  
  def logged_in?
    @logged_in
  end
  
  def save_ticket(dest_path)
    order = order_data.shift
    begin
      debug "* Fetching #{order.inspect}"
      fetch_ticket(order)
      debug "* Received ticket, saving as #{dest_path}"
      File.open(dest_path, 'w') { |f| f.write src }
      return true
    rescue Exception => e
      debug "* Ticket is unavailable"
      debug "* Exception: #{e.inspect}"
      File.open("#{RAILS_ROOT}/tmp/error_page", 'w') {|f| f.write src}
      return false
    end
  end
  
  def get_order_history
    debug "* Fetching and parsing a page of order history"
    fetch_order_history_page
  end





  private
  
  def login_loop
    while !logged_in?
      debug "* Gotta log in!"
      begin
        debug "* Requesting login page"
        goto_login_page

        debug "* Sending login request"
        log_in
      rescue
        debug "* Could not get logged in!"
        raise
      end
      debug "* Login successful"
    end
  end
  
  def fetch_order_history_page
    login_loop
    
    self.src = fetch_request("https://www.ticketmaster.com/member/order_history?start=#{pages_fetched}")
    self.doc = Hpricot(src)
    self.order_data ||= []
    rows = doc / "table.detailsTable tr"
    rows.shift # shift off the row of th elements
    puts "row size: #{rows.size}"
    rows.each do |row|
      self.order_data << {
        :order_date => row.at("//td[1]").innerHTML,
        :order_number => row.at("//td[2]/a").innerHTML.gsub('/', ' '),
        :event_name => row.at("//td[3]/strong").innerHTML,
        :venue_name => row.at("//td[3]/div[@class='smallText']").innerHTML.gsub(/<br.+$/m, ''),
        :event_date => row.at("//td[4]").innerHTML.strip,
        :get_tickets_uri => 'https://www.ticketmaster.com' + row.at("//td[3]//a")['href'] 
      } if row.at("//td[3]//a") 
    end
    self.pages_fetched += 1
  end
  
  def fetch_ticket(order_hash)
    login_loop
    
    debug "* Requesting order information page"
    self.src = fetch_request(order_hash[:get_tickets_uri])
    self.doc = Hpricot(src)
    
    refresh_loop
        
    if false # our tickets are not available
      # mark them as unavailable so we try again later
      return
    end
    
    raise "TM: we are having problems processing" if src =~ /We\s+are\s+having\s+problems\s+processing\s+your\s+tickets/
    raise "TM: We are currently processing the online delivery of your tickets" if src =~ /We\s+are\s+currently\s+processing\s+the\s+online\s+delivery\s+of\s+your\s+tickets/
    
    if(!doc.at("//div[@class='button']"))
      File.open("#{RAILS_ROOT}/tmp/bad_fetch_ticket",'w'){|f|f.write src}
    end
    
    uri = 'https://www.ticketmaster.com' + doc.at("//div[@class='button']")['onclick'].gsub(/^.*?\('(.*)'\)$/, '\1')
        
    debug "* Found order, loading tickets download window"
    self.src = fetch_request(uri)
    self.doc = Hpricot(src)
    
    refresh_loop
    
    uri = 'https://www.ticketmaster.com' + doc.at("//span[@class='messageText']/a")['href']
    
    self.src = fetch_request(uri, :binary => true)
    
    debug "* Tickets fetched"
  end
  
  def goto_login_page
    self.src = fetch_request('https://www.ticketmaster.com/member', :send_cookies => false)
    self.doc = Hpricot(src)
    raise "Site appears to be down?" unless doc.at("//input[@name='v']")
    self.form_data = {'v'             =>    doc.at("//input[@name='v']")['value'],
                      'email_address' =>    CGI::escape(self.username),
                      'password'      =>    CGI::escape(self.password) }
  end
  
  def log_in
    self.src = fetch_request('https://www.ticketmaster.com' + doc.at("//form[@name='sign_in']")['action'], :post_data => form_data)
    self.doc = Hpricot(src)
    raise 'Unable to log in' if doc.at("//form[@name='sign_in']")
    @logged_in = true 
  end
  
  def fetch_request(uri, options = {})
    default_options = {
      :send_cookies => true
    }
    options = default_options.merge(options)
    
    options[:cookies] = cookies if options[:send_cookies]
    
    job_key = self.username + rand(10000000).to_s
    
    count = 0
    loop do
      count += 1
      debug "Sending fetch_request call to job_queue_worker DONE THIS: #{count}"
      if count > 1
        debug "Dispatching a new client, logging in again then repeating request"
        @logged_in = false
        self.job_target = nil
        login_loop
      end
      
      sleep(rand)
      MiddleMan.worker(:job_queue_worker).async_fetch_request(:arg => {:client_key => job_key, :uri => uri, :options => options, :job_target => job_target})
    
      10.times do
        sleep(3)
        resp = nil
        begin
          Timeout.timeout(2) {
            resp = MiddleMan.worker(:job_queue_worker).fetch_response(:arg => {:client_key => job_key})
          }
        rescue Exception => e
          debug "Timed out!"
          debug e.inspect
        end
        
        if resp
          debug "*** got a response"
          if resp[:src] =~ /An error occurred while processing your request./
            debug "! sending request again got error processing request from TM"
            break
          end
          self.cookies = resp[:cookies]
          self.job_target = resp[:remote_ip]
          return resp[:src] 
        end
      end
    end
  end
  
  def refresh_loop
    loop do
      # check to make sure it is not a download page
      if src =~ /tickets\s+will\s+begin\s+downloading\s+automatically/
        debug "found download page!"
        return
      end
      
      http_refresh_el = doc.at("//meta[@http-equiv='refresh']")
      return if http_refresh_el.nil?
      debug "** In a refresh loop, waiting 4 seconds until trying again"
      uri = 'https://www.ticketmaster.com' + http_refresh_el['content'].gsub(/^.*?url=/,'')
      sleep(4)
      self.src = fetch_request(uri)
      self.doc = Hpricot(src)
    end
  end
end