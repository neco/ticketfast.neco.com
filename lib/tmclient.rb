require 'rubygems'
require 'hpricot'
require 'cgi'

class TMClient  
  attr_accessor :form_data, :doc, :src, :order_data, :pages_fetched
  
  def initialize(username='dgainor99@gmail.com', password='060381')
    @username, @password = username, password
    self.pages_fetched = 0
    self.order_data = []
  end
  
  def logged_in?
    @logged_in
  end
  
  def save_ticket(dest_path)
    begin
      fetch_ticket(order_data.first)
      puts "* Received ticket, saving as #{dest_path}"
      File.open(dest_path, 'w') { |f| f.write src }
      order_data.shift
    rescue
      puts "* Ticket is unavailable"
    end
  end
  
  def get_order_history
    unless logged_in?
      puts "* Requesting login page"
      goto_login_page
      pretend_to_be_human
    
      puts "* Sending login request"
      begin
        log_in
      rescue
        raise
      end
      puts "* Login successful"
      pretend_to_be_human
    end
    
    puts "* Fetching and parsing a page of order history"
    fetch_order_history_page
  end





  private
  
  
  def fetch_order_history_page
    self.src = fetch_request("https://www.ticketmaster.com/member/order_history?start=#{pages_fetched}")
    self.doc = Hpricot(src)
    self.order_data ||= []
    rows = doc / "table.detailsTable tr"
    rows.shift # shift off the row of th elements
    rows.each do |row|
      self.order_data << {
        :order_date => row.at("//td[1]").innerHTML,
        :order_number => row.at("//td[2]/a").innerHTML.gsub('/', ' '),
        :event_name => row.at("//td[3]/strong").innerHTML,
        :venue_name => row.at("//td[3]/div[@class='smallText']").innerHTML.gsub(/<br.+$/m, ''),
        :event_date => row.at("//td[4]").innerHTML.strip,
        :get_tickets_uri => 'https://www.ticketmaster.com' + row.at("//td[3]//a")['href'] 
      }
    end
    self.pages_fetched += 1
  end
  
  def fetch_ticket(order_hash)
    puts "* Requesting order information page"
    self.src = fetch_request(order_hash[:get_tickets_uri])
    self.doc = Hpricot(src)
    
    refresh_loop
        
    if false # our tickets are not available
      # mark them as unavailable so we try again later
      return
    end
    
    uri = 'https://www.ticketmaster.com' + doc.at("//div[@class='button']")['onclick'].gsub(/^.*?\('(.*)'\)$/, '\1')
    
    pretend_to_be_human
    
    puts "* Found order, loading tickets download window"
    self.src = fetch_request(uri)
    self.doc = Hpricot(src)
    
    refresh_loop
    
    puts "* Tickets fetched"
  end
  
  def goto_login_page
    self.src = fetch_request('https://www.ticketmaster.com/member', :send_cookies => false)
    self.doc = Hpricot(src)
    self.form_data = {'v'             =>    doc.at("//input[@name='v']")['value'],
                      'email_address' =>    CGI::escape(@username),
                      'password'      =>    CGI::escape(@password) }
  end
  
  def log_in
    self.src = fetch_request('https://www.ticketmaster.com/member/', :post_data => form_data)
    self.doc = Hpricot(src)
    raise 'Unable to log in' unless doc.at("//a[@href='https://www.ticketmaster.com/member/order_history?tm_link=mytm_myacct14']")
    @logged_in = true
  end
  
  def fetch_request(uri, options = {})
    default_options = {
      :send_cookies => true
    }
    options = default_options.merge(options)
    
    
    options[:post_data] = options[:post_data].collect{|k,v| "#{k}=#{v}"}.join('&') if options[:post_data]
    
    `curl -s #{"--data '#{options[:post_data]}' " if options[:post_data]} --insecure '#{uri}' -c mycookies #{'-b mycookies' if options[:send_cookies]}`
  end
  
  def refresh_loop
    loop do
      http_refresh_el = doc.at("//meta[@http-equiv='refresh']")
      return if http_refresh_el.nil?
      puts "** In a refresh loop, waiting 4 seconds until trying again"
      uri = 'https://www.ticketmaster.com' + http_refresh_el['content'].gsub(/^.*?url=/,'')
      sleep(4)
      self.src = fetch_request(uri)
      self.doc = Hpricot(src)
    end
  end
  
  def pretend_to_be_human
    puts
    puts "# kicking back, pretending i'm a human"
    print "3... "
    sleep(1)
    print "2... "
    sleep(1)
    puts "1... "
    puts
    sleep(1)
  end
end