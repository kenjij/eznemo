module EzNemo

  # ICMP ping plugin
  class Ping

    DEFAULT_MIN_INTERVAL = 10
    DEFAULT_TIMEOUT = 5

    attr_reader :monitor
    attr_reader :config

    def initialize
      os = RbConfig::CONFIG['host_os']
      case
      when os.include?('darwin')
        @os = 'bsd'
      when os.include?('linux')
        @os = 'linux'
      end
    end

    # Gets called by Monitor at regisration
    # @return [Symbol]
    def name
      return :ping
    end

    # Gets called by Monitor after regisration
    # @param mon [Object] parent Monitor object
    def registered(mon)
      @monitor = mon
      @config = EzNemo.config[:monitor][:ping] if EzNemo.config[:monitor]
      @config ||= {}
      @config[:path] ||= 'ping'
      @config[:min_interval] ||= DEFAULT_MIN_INTERVAL
      @config[:timeout] ||= DEFAULT_TIMEOUT
    end

    # Add a check using this plugin
    # @param check [Hash]
    def add_check(check)
      min = config[:min_interval]
      check[:interval] = min if check[:interval] < min
      EM.add_periodic_timer(check[:interval]) do
        self.send("#{@os}_ping", check)
      end
    end

    def linux_ping(check)
      result = {
        timestamp: Time.now,
        check_id: check[:id]
      }
      path = config[:path]
      timeout = config[:timeout]
      options = config[:cmd_opts]
      hostname = check[:hostname]
      cmd = "#{path} -c 1 -nqW #{timeout} #{options} #{hostname}"
      EM.system(cmd) do |output, status|
        case status.exitstatus
        when 0
          expr = /=\s*([0-9\.]+)/
          expr =~ output
          result[:status] = 1
          result[:response_ms] = $1.to_f
          result[:status_desc] = 'OK'
        when 1
          result[:status] = 0
          result[:response_ms] = 0
          result[:status_desc] = 'NG'
        else
          output = 'see log' if output.nil? || output.size == 0
          result[:status] = 0
          result[:response_ms] = 0
          result[:status_desc] = "ERROR: #{output}".chomp
        end
        monitor.report(result)
      end
    end

    def bsd_ping(check)
      result = {
        timestamp: Time.now,
        check_id: check[:id]
      }
      timeout = config[:timeout] * 1000
      options = config[:cmd_opts]
      hostname = check[:hostname]
      cmd = "#{path} -c 1 -nqW #{timeout} #{options} #{hostname}"
      EM.system(cmd) do |output, status|
        case status.exitstatus
        when 0
          expr = /=\s*([0-9\.]+)/
          expr =~ output
          result[:status] = 1
          result[:response_ms] = $1.to_f
          result[:status_desc] = 'OK'
        when 2
          result[:status] = 0
          result[:response_ms] = 0
          result[:status_desc] = 'NG'
        else
          result[:status] = 0
          result[:response_ms] = 0
          result[:status_desc] = "ERROR: #{output}".chomp
        end
        monitor.report(result)
      end
    end

  end

  monitor.register(Ping.new)

end
