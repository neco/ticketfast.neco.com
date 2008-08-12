class Event < ActiveRecord::Base
  has_many :tickets, :dependent => :destroy
  belongs_to :venue
  validates_uniqueness_of :code, :allow_nil => true
  
  def set_venue! venue_code
    self.venue = nil
    event_text = tickets.size > 0 ? tickets.first.event_text : ''
    venues = Venue.find_all_by_code venue_code
    venues.each do |v|
      if v.keyword and !v.keyword.empty?
        next unless event_text =~ /#{v.keyword}/i
        self.venue = v
      end
      self.venue = v unless venue
    end
    self.venue = Venue.create(:code => venue_code) unless venue
    save
  end
  
  def self.find_unnamed
    Event.find :all, :conditions => "name = '' OR name IS NULL"
  end
end
