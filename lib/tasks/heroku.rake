namespace :heroku do
  task :setup do
    RAILS_ENV = ENV['RAILS_ENV'] || 'production'
  end

  desc "Generate the Heroku gems manifest from gem dependencies"
  task :manifest => [:setup, :environment] do
    File.open(File.join(Rails.root, '.gems'), 'w') do |file|
      Rails.configuration.gems.each do |dependency|
        command, *options = dependency.send(:install_command)
        file.puts(options.join(' '))
      end
    end
  end
end
