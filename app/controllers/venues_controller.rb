class VenuesController < ApplicationController
  def manage
    @venues = Venue.all(:order => "code, name")
  end

  def search_by_code
    @venues = Venue.all(:conditions => "code like '%#{params[:code]}%'", :order => "code, name")
    request.xhr? ? render(:partial => "list") : render(:action => "manage")
  end

  def update
    params[:venue_names].each do |key, value|
      next if value.empty?
      v = Venue.find(key)
      v.name = value
      v.save
    end if params[:venue_names]

    params[:venue_keywords].each do |key, value|
      next if value.empty?
      v = Venue.find(key)
      v.keyword = value
      v.save
      v.events.each { |event| event.set_venue!(v.code) }
    end if params[:venue_keywords]

    redirect_to :action => "manage"
  end

  def destroy
    Venue.find(params[:id]).destroy
    render :text => ''
  end
end
