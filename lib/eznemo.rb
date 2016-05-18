require 'eznemo/logger'
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
      p = c[:probe]
      EzNemo.logger = eval(p[:logger]) if p[:logger].class == String
      logger = EzNemo.logger
      logger.level = eval(p[:log_level]) if p[:log_level].class == String
      logger.debug 'Loading datastore adapter...'
      require "eznemo/#{c[:datastore][:type]}"
      require 'eznemo/datastore'
      logger.debug 'Loading monitoring plugins...'
      require 'eznemo/monitor'
      require 'eznemo/monitor/ping'
    end

    # Usually called by #self.run!
    def run
      logger = EzNemo.logger
      ds = EzNemo.datastore

      Signal.trap('INT') do
        puts 'Interrupted.'
        ds.flush
        exit
      end

      Signal.trap('SIGTERM') do
        puts 'Stopping...'
        ds.flush
        exit
      end
      
      EM.run do
        logger.debug 'Loading checks...'
        EzNemo.monitor.start_checks(ds.checks)
        ds.start_loop
      end
    end

  end

end
