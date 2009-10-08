class Ticket < ActiveRecord::Base
  belongs_to :event
  belongs_to :tm_account
  has_many :ticket_actions, :order => "created_at DESC"

  validates_uniqueness_of :barcode_number, :allow_nil => true

  archived = { :archived => false }
  named_scope :unparsed, :conditions => archived.merge(:unparsed => true)
  named_scope :unfetched, :conditions => archived.merge(:unfetched => true)
  named_scope :fetched, :conditions => archived.merge(:unfetched => false)

  def before_destroy
    `rm #{Rails.root}/#{Settings.pdf_dir}/#{id}.pdf`
  end

  def create_quickview!
    `cd #{Rails.root} && pdf2dsc #{pdf_rel_filepath} #{Rails.root}/tmp/#{id}.dsc`
    `convert #{Rails.root}/tmp/#{id}.dsc #{jpg_filepath}`
    `rm #{Rails.root}/tmp/#{id}.dsc`
    has_quickview?
  end

  def has_quickview?
    File.exists?(jpg_filepath)
  end

  def pdf_filepath
    "#{Rails.root}/#{pdf_rel_filepath}"
  end

  def pdf_rel_filepath
    "#{Settings.pdf_dir}/#{id}.pdf"
  end

  def jpg_filepath
    "#{Rails.root}/#{Settings.pdf_dir}/jpgs/#{id}.jpg"
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

    events = Event.find_by_sql <<-SQL
      SELECT DISTINCT events.occurs_at
      FROM
        tickets
        LEFT OUTER JOIN events ON events.id = tickets.event_id
        LEFT OUTER JOIN venues ON venues.id = events.venue_id
      WHERE #{conditions}
      ORDER BY events.occurs_at DESC"
    SQL

    events.collect { |obj| obj.occurs_at }
  end

  def self.find_by_search(query, conditions = nil, include_ticket_actions=nil)
    conditions = Ticket.prepare_conditions_for_search(query, conditions)

    Ticket.all(
      :conditions => conditions,
      :include => ([{ :event => :venue }] + (include_ticket_actions ? [:ticket_actions] : [])),
      :order => Ticket.order_clause,
      :limit => 150
    )
  end

  def self.prepare_conditions_for_search(query, conditions = nil)
    queries = query.gsub(/'/, "\\'").split(" ")
    conditions ||= "1=1"

    queries.each do |query|
      next if query.empty?
      conditions << " AND (tickets.section LIKE '%#{query}%' " +
      conditions << "OR tickets.row LIKE '%#{query}%' OR " +
      conditions << "tickets.seat LIKE '%#{query}%' OR " +
      conditions << "tickets.purchaser LIKE '%#{query}%' OR " +
      conditions << "tickets.order_number LIKE '%#{query}%' OR " +
      conditions << "tickets.barcode_number LIKE '%#{query}%' OR " +
      conditions << "events.code LIKE '%#{query}%' OR " +
      conditions << "events.name LIKE '%#{query}%' OR " +
      conditions << "tickets.event_text LIKE '%#{query}%')"
    end

    conditions
  end
end
