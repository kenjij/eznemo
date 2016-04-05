require 'eznemo/config'
require 'eznemo/version'
require 'eventmachine'

module EzNemo

  # EventMachine reactor
  class Reactor

    # Start reactor
    # @param opts [Hash] from command line
    # @return [Object]
    def self.run!(opts)
      r = Reactor.new(opts)
      r.run
      r
    end

    # Usually called by #self.run!
    def initialize(opts)
      c = EzNemo.load_config(opts[:config])

      require "eznemo/#{c[:datastore][:type]}"
      require 'eznemo/datastore'

      require 'eznemo/monitor'
      require 'eznemo/monitor/ping'
    end

    # Usually called by #self.run!
    def run
      ds = EzNemo.datastore

      Signal.trap('INT') do
        puts 'Interrupted. Flushing...'
        ds.flush
        exit
      end

      Signal.trap('SIGTERM') do
        puts 'Stopping...'
        ds.flush
        exit
      end
      
      EM.run do
        EzNemo.monitor.start_checks(ds.checks)
      end
    end

  end

end
