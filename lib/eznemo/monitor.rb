require 'json'

module EzNemo

  # The shared Monitor instance
  # @return [EzNemo::Monitor]
  def self.monitor
    @monitor ||= Monitor.new
  end

  # Maintains an array of all the monitor plugins
  class Monitor

    def initialize
      @plugins = {}
    end

    # Registers a plugin; usually called by the plugin itself
    # @param plugin [Object]
    def register(plugin)
      @plugins[plugin.name] = plugin
      plugin.registered(self)
    end

    # Starts check loops in the reactor
    # @param checks [Array<Hash, ...>]
    def start_checks(checks)
      cfg_tags = EzNemo.config[:checks][:tags]
      i = 0
      checks.each do |c|
        if cfg_tags
          c[:tags] ? tags = JSON.parse(c[:tags]) : tags = []
          next if (cfg_tags & tags).empty?
        end
        p = @plugins[c[:type].to_sym]
        p.add_check(c)
        i += 1
      end
      puts "#{i} checks activated."
    end

    # Report result; usually called by the plugin
    # @param result [Hash] :check_id, :timestamp, :status, :response_ms, :status_desc
    def report(result)
      EzNemo.datastore.store_result(result)
    end

  end

end
