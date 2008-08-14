default_run_options[:pty] = true

set :application, "ticketfast"
set :repository,  "git@github.com:benjohnson/ticketfast.git"
set :keep_releases, 5

set :scm, :git
set :deploy_via, :remote_cache # prevent git from cloning on every deploy
set :deploy_to, "/var/rails/#{application}"
set :branch, "master"

set :mongrel_conf, "#{current_path}/config/mongrel_cluster.yml" # must be set after :deploy_to is set

set :user, 'root'
set :runner, 'root'
set :use_sudo, false

role :app, "server2.neco.com"
role :web, "server2.neco.com"
role :db,  "server2.neco.com", :primary => true

task :after_update_code do
  # handle shared files
  %w{/config/database.yml /config/mongrel_cluster.yml /bin /pdfs}.each do |file|
    run "ln -nfs #{shared_path}#{file} #{release_path}#{file}"
  end
end

namespace :deploy do
  namespace :mongrel do
    [ :stop, :start, :restart ].each do |t|
      desc "#{t.to_s.capitalize} the mongrel appserver"
      task t, :roles => :app do
        #invoke_command checks the use_sudo variable to determine how to run the mongrel_rails command
        invoke_command "mongrel_rails cluster::#{t.to_s} -C #{mongrel_conf}", :via => run_method
      end
    end
  end

  desc "Custom restart task for mongrel cluster"
  task :restart, :roles => :app, :except => { :no_release => true } do
    deploy.mongrel.restart
  end

  desc "Custom start task for mongrel cluster"
  task :start, :roles => :app do
    deploy.mongrel.start
  end

  desc "Custom stop task for mongrel cluster"
  task :stop, :roles => :app do
    deploy.mongrel.stop
  end
  
  namespace :web do
    desc "Serve up custom maintenance page."
    task :disable, :roles => :web do
      require "erb"
      on_rollback { run "rm #{shared_path}/system/maintenance.html" }
      
      reason = ENV['REASON']
      deadline = ENV['UNTIL']
      template = File.read("app/views/layouts/maintenance.html.erb")
      page = ERB.new(template).result(binding)
      
      put page, "#{shared_path}/system/maintenance.html", :mode => 0644
    end
  end
end