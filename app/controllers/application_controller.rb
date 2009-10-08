# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  before_filter :assign_empty_js_includes

  def assign_empty_js_includes
    @js_includes = []
  end
end
