class Event < ActiveRecord::Base
  belongs_to :venue
  has_many :tickets, :dependent => :destroy

  validates_uniqueness_of :code, :allow_nil => true

  named_scope :unnamed, :conditions => "name = '' OR name IS NULL"
  named_scope :without_dates, :conditions => 'occurs_at IS NULL'

  def set_venue! venue_code
    self.venue = nil
    event_text = tickets.size > 0 ? tickets.first.event_text : ''
    venues = Venue.find_all_by_code(venue_code)

    venues.each do |v|
      if v.keyword && !v.keyword.empty?
        next unless event_text =~ /#{v.keyword}/i
        self.venue = v
      end

      self.venue = v unless venue
    end

    self.venue = Venue.create(:code => venue_code) unless venue
    save
  end

  def self.find_unnamed
    all(:conditions => "name = '' OR name IS NULL")
  end
end
