default_run_options[:pty] = true

set :application, "ticketfast.neco.com"
set :repository,  "git@github.com:binarylogic/ticketfast.neco.com.git"
set :keep_releases, 5

set :scm, :git
set :deploy_via, :remote_cache # prevent git from cloning on every deploy
set :deploy_to, "/var/www/#{application}"
set :branch, "master"

set :thin_conf, "#{current_path}/config/thin.yml" # must be set after :deploy_to is set

set :user, 'root'
set :runner, 'root'
set :use_sudo, false

role :app, "server2.neco.com"
role :web, "server2.neco.com"
role :db,  "server2.neco.com", :primary => true

task :after_update_code do
  # handle shared files
  %w{/config/database.yml /config/thin.yml /bin /pdfs}.each do |file|
    run "ln -nfs #{shared_path}#{file} #{release_path}#{file}"
  end
  
  deploy.cleanup
end

set :mysql_username, 'tf_user'
set :mysql_password, 'fv38vdl2'
set :mysql_production_db, 'ticketfast_production'
set :mysql_host, '10.10.1.11'

def run_local cmd
  puts %[  * executing locally "#{cmd}"]
  `#{cmd}`
end

namespace :dev do
  desc 'Import DB and PDFs'
  task :sync do
    dev.import_production_db
    dev.import_pdfs
  end
  
  desc 'Retrieve current production database and import locally.'
  task :import_production_db do 
    n = Time.now

    file = "ticketfast-#{sprintf("%d%02d%02d%02d%02d", n.year, n.month, n.day, n.hour, n.min)}.sql"
    remote_path = "/root/#{file}"

    on_rollback { run "rm #{remote_path}" }

    run "mysqldump -u #{mysql_username} -p #{mysql_production_db} -h #{mysql_host} > #{remote_path}" do |ch, stream, out|
      ch.send_data "#{mysql_password}\n" if out =~ /^Enter password:/
    end

    run_local "rsync #{user}@#{roles[:db].servers.first.host}:#{remote_path} ."
    run "rm #{remote_path}"

    run_local "rake db:drop"
    run_local "rake db:create"
    run_local "mysql -u root ticketfast_development < #{file}"
    run_local "rake db:migrate"
  end
  
  desc 'Copy pdfs from production server'
  task :import_pdfs do
    run_local "rsync -r #{user}@#{roles[:db].servers.first.host}:/var/www/ticketfast.neco.com/current/pdfs/* pdfs/"
  end
end

namespace :deploy do
  namespace :thin do
    [ :stop, :start, :restart ].each do |t|
      desc "#{t.to_s.capitalize} the thin servers"
      task t, :roles => :app do
        #invoke_command checks the use_sudo variable to determine how to run the thin command
        invoke_command "thin #{t.to_s} -C #{thin_conf}", :via => run_method
      end
    end
  end

  desc "Custom restart task for thin cluster"
  task :restart, :roles => :app, :except => { :no_release => true } do
    deploy.thin.restart
  end

  desc "Custom start task for thin cluster"
  task :start, :roles => :app do
    deploy.thin.start
  end

  desc "Custom stop task for thin cluster"
  task :stop, :roles => :app do
    deploy.thin.stop
  end
end