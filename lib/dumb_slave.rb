require 'cgi'
require 'timeout'
require "base64"

class DumbSlave
  def initialize
    @base_uri = 'http://ticketfast.neco.com/'
    #@base_uri = 'http://localhost:3000/'
  end
  
  def get_job
    Marshal.load(Base64.decode64(fetch_request("#{@base_uri}ticket_request_server/get_job", :send_cookies => false)))
  end
  
  def work
    loop do
      job = nil
      begin
        puts "Asking for work"
        Timeout.timeout(10) {
          job = get_job
        }
      rescue Exception => e
        puts "Error: #{e.to_s}\nTrying again in 30 seconds"
        sleep(30)
        next
      end
      
      puts "Received job: #{job.inspect}"
      
      case job[:action]
        when :sleep
          puts "* Sleeping for #{job[:duration]} seconds"
          sleep(job[:duration])
        when :instance_eval
          puts "* Evaluating the following code"
          puts job[:eval_code]
          instance_eval(job[:eval_code])
        when :fetch_request
          puts "* Fetching request"
          do_fetch_request_job(job)
      end
    end
  end
  
  def do_fetch_request_job(job)
    src = fetch_request(job[:uri], job[:options])
    cookies = File.read('mycookies')
    results_str = Base64.encode64(Marshal.dump({:src => src, :cookies => cookies}))
    fetch_request("#{@base_uri}ticket_request_server/submit_work", :send_cookies => false, :post_data => {'results' => CGI::escape(results_str), 'client_key' => CGI::escape(job[:client_key])})
  end
  
  def fetch_request(uri, options = {})        
    File.open('cookies', 'w') {|f| f.write options[:cookies]} if options[:cookies]
    
    if options[:post_data]
      options[:post_data] = options[:post_data].collect{|k,v| "#{k}=#{v}"}.join('&') 
      File.open('postdata', 'w') {|f| f.write options[:post_data]}
    end
    
    `curl -s #{%[--data "@postdata" ] if options[:post_data]} --insecure "#{uri}" -c mycookies #{'-b cookies' if options[:send_cookies]} -u "neco:fast tickets"`
  end
end

if ARGV[0] == 'start'
  slave = DumbSlave.new
  slave.work
else
  puts "Usage: dumb_slave start"
end