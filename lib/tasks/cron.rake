task :cron do
  Rake::Task['mail:process'].invoke
  Rake::Task['mail:fetch'].invoke
end
