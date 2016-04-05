ropts = {
  :redirects => 5,
  :keepalive => false
}
EM.run {
  http = EM::HttpRequest.new('http://www.yahoo.com/').head(ropts)

  http.errback { p 'Uh oh'; EM.stop }
  http.callback {
    p http.response_header.status
    p http.response_header
    p http.response

    EM.stop
  }
}



module EzNemo

  class HTTP

    def initialize
    end

    def name
      return :http
    end

    def add_check(check, m)
      check[:interval] = MIN_INTERVAL if check[:interval] < MIN_INTERVAL
      EM.add_periodic_timer(check[:interval]) do
        result = self.send("#{@os}_ping", check[:hostname], check[:options])
        result[:check_id] = check[:id]
        m.report(result)
      end
    end

    def ping()
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

  monitor.register(HTTP.new)

end
