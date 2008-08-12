class Ticket < ActiveRecord::Base
  validates_uniqueness_of :barcode_number, :allow_nil => true
  belongs_to :event
  has_many :ticket_actions, :order => "created_at DESC"
  
  def before_destroy
    `rm #{RAILS_ROOT}/#{Setting['pdf_dir']}/#{id}.pdf`
  end
  
  def pdf_filepath
    "#{RAILS_ROOT}/#{Setting['pdf_dir']}/#{id}.pdf"
  end
  
  def view!
    self.viewed = true
    save
  end
  
  def unview!
    self.viewed = false
    save
  end
  
  def self.order_clause
    "events.occurs_at DESC, events.id, tickets.section, tickets.row, tickets.seat"
  end
  
  def self.find_event_dates_by_search(query, conditions = nil)
    conditions = Ticket.prepare_conditions_for_search query, conditions
    events = Event.find_by_sql "SELECT DISTINCT events.occurs_at FROM tickets LEFT OUTER JOIN 
      events ON events.id = tickets.event_id LEFT OUTER JOIN 
      venues ON venues.id = events.venue_id WHERE
      #{conditions}
      ORDER BY events.occurs_at DESC"
    events.collect{|obj| obj.occurs_at}
  end

  def self.find_by_search(query, conditions = nil, include_ticket_actions=nil)
    conditions = Ticket.prepare_conditions_for_search query, conditions
    Ticket.find :all, :conditions => conditions, :include => ([{:event => :venue}] + 
(include_ticket_actions ? [:ticket_actions] : [])), 
:order => Ticket.order_clause, :limit => 150
  end
  
  def self.prepare_conditions_for_search(query, conditions = nil)
    queries = query.gsub(/'/, "\\'").split(" ")
    conditions ||= "1=1"
    queries.each do |query|
      next if query.empty?
      conditions +=  " AND (tickets.section LIKE '%#{query}%' " +
                    "OR tickets.row LIKE '%#{query}%' OR " +
                    "tickets.seat LIKE '%#{query}%' OR " + 
                    "tickets.purchaser LIKE '%#{query}%' OR " +
                    "tickets.order_number LIKE '%#{query}%' OR " + 
                    "tickets.barcode_number LIKE '%#{query}%' OR " + 
                    "events.code LIKE '%#{query}%' OR " +
                    "events.name LIKE '%#{query}%' OR " + 
                    "tickets.event_text LIKE '%#{query}%')"
    end
    conditions
  end
end
