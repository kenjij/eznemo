module EzNemo

  # ICMP ping plugin
  class Ping

    attr_reader :monitor

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
    end

    # Add a check using this plugin
    # @param check [Hash]
    def add_check(check)
      check[:interval] = MIN_INTERVAL if check[:interval] < MIN_INTERVAL
      EM.add_periodic_timer(check[:interval]) do
        self.send("#{@os}_ping", check)
      end
    end

    def linux_ping(check)
      result = {
        timestamp: Time.now,
        check_id: check[:id]
      }
      cmd = "ping -c 1 -nqW 4 #{check[:hostname]}"
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
      cmd = "ping -c 1 -nqW 4000 #{check[:hostname]}"
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
