require 'yaml'

module EzNemo

  # Load YAML config file
  # @param path [String] config file
  # @return [Object] config; a shared instance
  def self.load_config(path)
    raise 'config file missing' unless path
    @config ||= YAML.load_file(path)
  end

  # see #self.load_config
  def self.config
    @config
  end

end
