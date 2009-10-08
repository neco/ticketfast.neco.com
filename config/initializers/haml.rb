Haml::Template.options[:attr_wrapper] = '"'
Sass::Plugin.options[:style] = Rails.env.production? ? :compressed : :expanded
