class Venue < ActiveRecord::Base
  has_many :events, :dependent => :destroy
  has_many :tickets, :through => :events
  
  def self.find_unnamed
    Venue.find :all, :conditions => "name = '' OR name IS NULL"
  end
end
