require 'timeout'

class TicketsMailerQueue
  def self.process_queue
    while t = self.pop
      begin
        Timeout.timeout(20) do
          TicketsMailer.deliver_attached_pdf *t
        end

      rescue Timeout::Error => e
        self.push *t
        sleep 60
      end
    end
  end

  def self.queue_file
    @@queue_file ||= Settings.mailer_queue
  end

  def self.get_queue
    queue = nil

    begin
      queue = Marshal.load(File.read(queue_file))
    rescue
    end

    queue || []
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
