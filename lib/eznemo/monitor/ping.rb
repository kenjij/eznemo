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
    # @param check [EzNemo::Check]
    def add_check(check)
      min = config[:min_interval]
      check[:interval] = min if check[:interval] < min
      EM.add_periodic_timer(check[:interval]) do
        self.send("#{@os}_ping", check)
      end
    end

    def linux_ping(check)
      result = create_result_for_check(check)
      EM.system(build_cmd(check)) do |output, status|
        case status.exitstatus
        when 0
          expr = /=\s*([0-9\.]+)/
          expr =~ output
          set_ok_result(result, $1.to_f)
        when 1
          set_ng_result(result)
        else
          set_error_result(result, output)
        end
        monitor.report(result)
      end
    end

    def bsd_ping(check)
      result = create_result_for_check(check)
      args = {timeout: config[:timeout] * 1000}
      EM.system(build_cmd(check, args)) do |output, status|
        case status.exitstatus
        when 0
          expr = /=\s*([0-9\.]+)/
          expr =~ output
          set_ok_result(result, $1.to_f)
        when 2
          set_ng_result(result)
        else
          set_error_result(result, output)
        end
        monitor.report(result)
      end
    end

    private

    # @param check [EzNemo::Check]
    # @return [EzNemo::Result]
    def create_result_for_check(check)
      Result::new do |r|
        r.timestamp = Time.now
        r.check = check
        r.probe = EzNemo.config[:probe][:name]
      end
    end

    # @param check [EzNemo::Check]
    # @param args [Hash] overriding arguments
    def build_cmd(check, args = {})
      h = {
        path: config[:path],
        timeout: config[:timeout],
        options: "#{config[:cmd_opts]} #{check[:options]}",
        hostname: check[:hostname]
      }
      h.merge!(args)
      "#{h[:path]} -c 1 -nqW #{h[:timeout]} #{h[:options]} #{h[:hostname]}"
    end

    def set_ok_result(result, ms)
      result.status = true
      result.response_ms = ms
      result.status_desc = 'OK'
    end

    def set_ng_result(result)
      result.status = false
      result.response_ms = 0
      result.status_desc = 'NG'
    end

    def set_err_result(result, msg)
      msg = 'see log' if msg.nil? || msg.size == 0
      result.status = false
      result.response_ms = 0
      result.status_desc = "ERROR: #{msg}".chomp
    end

  end

  monitor.register(Ping.new)

end
