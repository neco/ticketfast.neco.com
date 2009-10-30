# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  before_filter :authenticate
  before_filter :assign_empty_js_includes

  def authenticate
    authenticate_or_request_with_http_basic do |username, password|
      username == 'neco' && password == 'hurricane123'
    end
  end
  protected :authenticate

  def assign_empty_js_includes
    @js_includes = []
  end
  protected :assign_empty_js_includes
end
