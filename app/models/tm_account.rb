class TmAccount < ActiveRecord::Base
  has_many :tickets
  named_scope :enabled, :conditions => {:disabled => false}
end
