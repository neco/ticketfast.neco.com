class EventsController < ApplicationController
  auto_complete_for :event, :name, :select => 'distinct name'

  alias_method :real_auto_complete_for_event_name, :auto_complete_for_event_name

  def auto_complete_for_event_name
    unless params[:event] and params[:event][:name] and !params[:event][:name].empty?
      params[:event] = {}
      params[:event][:name] = params[:event_names].to_a.first.last 
    end
    real_auto_complete_for_event_name
  end

  def index
    @events = Event.find :all
  end
  
  def delete_all
    Event.destroy_all
    redirect_to :action => "index"
  end

  def manage
    if params[:event] and params[:event][:name] and !params[:event][:name].empty?
      @events = Event.find(:all, :conditions => ['name like ?', params[:event][:name]])
    else
      @events = Event.find_unnamed
    end
  end
  
  def update_unnamed
    params[:event_names].each do |key, value| next if value.empty?
      e = Event.find(key)
      e.name = value
      e.save
    end if params[:event_names]
    params[:venue_names].each do |key, value| next if value.empty?
      v = Venue.find(key)
      v.name = value
      v.save
    end if params[:venue_names]
    redirect_to :action => "manage"
  end
end
