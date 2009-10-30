# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.2' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  config.gem 'chronic', :version => '~> 0.2.3'
  config.gem 'haml', :version => '~> 2.0.9'
  config.gem 'settingslogic', :version => '~> 1.0.0'
  config.gem 'packet', :version => '~> 0.1.15'
  config.gem 'right_aws', :version => '~> 1.10.0'
end
