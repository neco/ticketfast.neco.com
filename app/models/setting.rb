class Setting
  def self.settings
    @@application_settings ||= YAML.load(File.read("#{Rails.root}/config/application_settings.yml"))
  end

  def self.[] key
    Setting.settings[key]
  end
end
