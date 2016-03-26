require 'eznemo/config'
require 'eznemo/version'
require 'eventmachine'

module EzNemo

  class Reactor

    def self.run!(opts)
      r = Reactor.new(opts)
      r.run
    end

    def initialize(opts)
      c = EzNemo.load_config(opts[:config])

      require "eznemo/#{c[:datastore][:type].to_s}"
      require 'eznemo/datastore'
      
      require 'eznemo/monitor'
      require 'eznemo/ping'
    end

    def run
      d = EzNemo.datastore
      
      Signal.trap('INT') do
        puts 'Interrupted. Flushing...'
        d.flush
        exit
      end
      
      Signal.trap('SIGTERM') do
        puts 'Stopping...'
        d.flush
        exit
      end
      
      EM.run do
        EzNemo.monitor.activate_checks(d.checks)
      end
    end

  end

end
