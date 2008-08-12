class Wiseguys
  def self.get_new
    root_url = "https://brokers.wiseguytickets.com/3113/2007/Ticketfast/"
    main_page = "frame_index.html"
    username = "3113"
    password = "RNqIUdjH" 
    last_check_filepath = "#{RAILS_ROOT}/config/wiseguys_last_check"
    data = `curl -u #{username}:#{password} --basic -k #{root_url}#{main_page}`
   
    results = data.scan(/<td>.*?href="(.*?)".*?<\/td>.*?<td>([^>]*?)<\/td><\/tr>/)
    last_time = Time.parse(File.read(last_check_filepath))
    newest_time = last_time
    items_hash = {}
    results.each do |group|
      items_hash[Time.parse(group[1])] ||= []
      items_hash[Time.parse(group[1])] << root_url + 
        group[0].split('/').collect{|a|ERB::Util.url_encode(a)}.join('/')
    end
    sorted_items = items_hash.sort 
    sorted_items.each do |date_and_urls|
      time = date_and_urls[0]
      puts "This: #{time}, Last: #{last_time}"
      next unless time > last_time
      newest_time = time if time > newest_time
      date_and_urls[1].each do |dest_url|
        puts "Accessing URL: #{dest_url}"
        data = `curl -u #{username}:#{password} --basic -k "#{dest_url}"`
        pdf_urls = data.scan(/href="(.*?pdf)"/).collect{|arr| dest_url.match(/^(.*\/)[^\/]+$/)[1] + ERB::Util.url_encode(arr.first)}
        pdf_urls.each do |pdf_url|
          `curl -u #{username}:#{password} --basic -k -o "#{RAILS_ROOT}/tmp/wiseguys_#{pdf_url.match(/\/([^\/]+)$/)[1]}" "#{pdf_url}"`
        end
        TicketsMailer.deliver_wiseguys_pdfs
        `rm -f #{RAILS_ROOT}/tmp/wiseguys*pdf`
      end
      File.open(last_check_filepath, 'w') {|io| io.write newest_time}
    end
  end
end
