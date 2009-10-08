class EventsController < ApplicationController
  auto_complete_for :event, :name, :select => 'distinct name'

  alias_method :real_auto_complete_for_event_name, :auto_complete_for_event_name

  def auto_complete_for_event_name
    unless params[:event] && !params[:event][:name].blank?
      params[:event] = {}
      params[:event][:name] = params[:event_names].to_a.first.last
    end

    real_auto_complete_for_event_name
  end

  def index
    @events = Event.all
  end

  def delete_all
    Event.destroy_all
    redirect_to :action => "index"
  end

  def manage
    if params[:event] && !params[:event][:name].blank?
      @events = Event.all(:conditions => ['name LIKE ?', params[:event][:name]])
    elsif params[:no_dates]
      @events = Event.without_dates
    else
      @events = Event.find_unnamed
    end
  end

  def update_unnamed
    out = ''

    params[:event_names].each do |key, value| next if value.empty?
      Event.find(key).update_attributes(:name => value)
    end if params[:event_names]

    params[:venue_names].each do |key, value| next if value.empty?
      e = Event.find(key)
      e.venue ||= Venue.new
      e.venue.update_attributes(:name => value)
      e.save
    end if params[:venue_names]

    params[:event_dates].each do |key, value| next if value.empty?
      e = Event.find(key)
      new_time = Time.parse(value)

      unless e.occurs_at == Time.parse(value)
        e.occurs_at = new_time
        e.save
      end
    end

    redirect_to :action => "manage"
  end
end
