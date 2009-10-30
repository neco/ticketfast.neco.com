unless File.directory?(Settings.tmp_dir)
  FileUtils.mkdir_p(Settings.tmp_dir)
end

unless File.directory?(Settings.pdf_dir)
  FileUtils.mkdir_p(Settings.pdf_dir)
end

unless File.directory?(File.dirname(Settings.mailer_queue))
  FileUtils.mkdir_p(File.dirname(Settings.mailer_queue))
end
