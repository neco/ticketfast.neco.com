require 'timeout'
class TicketsMailerQueue
  def self.process_queue
    while(t = self.pop)
      begin
        puts "Trying to shoot an email off, will timeout in 20 seconds"
        Timeout.timeout(20) {
          puts t.inspect
          TicketsMailer.deliver_attached_pdf *t
        }
        puts "Success"
      rescue Timeout::Error => e
        puts "Failed, putting it back on the queue, waiting 60 seconds to try again..."
        self.push *t
        sleep 60
      end
    end
    puts "All done, queue should be empty."
  end

  def self.queue_file
    @@queue_file ||= "#{RAILS_ROOT}/config/mailer_queue"
  end

  def self.get_queue
    queue = nil
    begin
      queue = Marshal.load(File.read(queue_file))
    rescue;end
    queue ||= []
  end

  def self.set_queue queue
    File.open(self.queue_file, 'w') { |f| f.write Marshal.dump(queue) }
  end

  def self.push(*params)
    queue = self.get_queue
    queue.push params
    self.set_queue queue
  end

  def self.pop
    queue = self.get_queue
    val = queue.pop
    self.set_queue queue
    val
  end

end
