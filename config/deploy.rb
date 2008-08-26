default_run_options[:pty] = true

set :application, "ticketfast.neco.com"
set :repository,  "git@github.com:binarylogic/ticketfast.neco.com.git"
set :keep_releases, 5

set :scm, :git
set :deploy_via, :remote_cache # prevent git from cloning on every deploy
set :deploy_to, "/var/www/#{application}"
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
  
  desc 'Copy photos from production server'
  task :import_pdfs do
    run_local "rsync -r #{user}@#{roles[:db].servers.first.host}:/var/www/ticketfast.neco.com/current/pdfs/* pdfs/"
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
end