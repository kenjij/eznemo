require 'yaml'

module EzNemo

  def self.load_config(path)
    raise 'config file missing' unless path
    @config ||= YAML.load_file(path)
  end

  def self.config
    @config
  end

end
