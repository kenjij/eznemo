require 'json'

module EzNemo

  MIN_INTERVAL = 5

  def self.monitor
    @monitor ||= Monitor.new
  end

  class Monitor

    def initialize
      @plugins = {}
    end

    def register(p)
      @plugins[p.name] = p
    end

    def activate_checks(checks)
      cfg_tags = EzNemo.config[:datastore][:tags]
      i = 0
      checks.each do |c|
        if cfg_tags
          c[:tags] ? tags = JSON.parse(c[:tags]) : tags = []
          next if (cfg_tags & tags).empty?
        end
        p = @plugins[c[:type].to_sym]
        p.add_check(c, self)
        i += 1
      end
      puts "#{i} checks activated."
    end

    def report(result)
      EzNemo.datastore.store_result(result)
    end

  end

end
