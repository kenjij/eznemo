module EzNemo

  class Ping

    def initialize
      os = RbConfig::CONFIG['host_os']
      case
      when os.include?('darwin')
        @os = 'bsd'
      when os.include?('linux')
        @os = 'linux'
      end
    end

    def name
      return :ping
    end

    def add_check(check, m)
      check[:interval] = MIN_INTERVAL if check[:interval] < MIN_INTERVAL
      EM.add_periodic_timer(check[:interval]) do
        result = self.send("#{@os}_ping", check[:hostname], check[:options])
        result[:check_id] = check[:id]
        m.report(result)
      end
    end

    def linux_ping(hostname, opts = nil)
      result = {timestamp: Time.now}
      output = `ping -c 1 -nqW 2 #{hostname} 2>&1`
      case $?.exitstatus
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
        result[:status] = 0
        result[:response_ms] = 0
        result[:status_desc] = "ERROR: #{output}".chomp
      end
      result
    end

    def bsd_ping(hostname, opts = nil)
      result = {timestamp: Time.now}
      output = `ping -c 1 -nqW 1 #{hostname} 2>&1`
      case $?.exitstatus
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
      result
    end

  end

  monitor.register(Ping.new)

end
