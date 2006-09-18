#!/usr/bin/ruby
#
# eznemo.rb - A simple host monitoring with TCP ping.
# ver.0.8beta (2006-09-17)
# (c) 2006 CYANandBLUE
#
# License:
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


##
## Dependencies
##
require 'ipaddr'
require 'net/smtp'
require 'ping'
require 'thread'


##
## System parameters
##
S_SYSTEMNAME = 'EzNemo ver.0.8beta - (c) 2006 CYANandBLUE'
I_PINGTIMEOUT_MAX = 10
I_PINGINTERVAL_MIN = 60
I_PINGRETRY_MAX = 10
S_HTMLBASEPATH = './status.html'

S_LOGDATEFORMAT = '%Y-%m-%dT%H:%M:%S%Z'
S_REPORTDATEFORMAT = '%c'


##
## Default setting (variables will be reset by configuration)
##
$i_pingtimeout = 1
$i_pingport = 7
$i_pinginterval = 300
$i_pingretry = 2
$s_smtpserver = '127.0.0.1'
$i_smtpport = 25
$s_smtpdomain = ''
$s_emailfrom = ''
$a_emailalarm = []
$s_alarmsubject = 'EzNemo ALARM'
$s_reportpath = './eznemo.html'

$h_initconfig = {}
$s_html_initconf = ''
# $q_msg = {'time' => , 'ipaddr' => , 'status' => , 'type' => , }
$q_msg = Queue.new
# $h_host = {ip_addr => comment} (when reading conf)
# $h_host = {ip_addr => #Host} (at host init)
$h_host = {}


##
## Pre-defined functions
##

# Sends and email through the directed SMTP server.
def email(body)
  body = "Subject: " + $s_alarmsubject + "\n\n" + body
  Net::SMTP.start($s_smtpserver, $i_smtpport, $s_smtpdomain) do |smtp|
    smtp.send_message body, $s_emailfrom, $a_emailalarm
  end
rescue
  $msg.error($!)
end


##
## Class definitions
##

# Message handler class
#  Handles internal message outputs depending on the type.
#  Message.event  : Any action can be an event if the hosts status does not change. A line will output to the STDOUT.
#  Message.stderr : System message. A line will output to the STDERR.
#  Message.error  : Whenever something unexpected happens. A line will output to the STDERR.
#  Message.alarm  : Whenever the hosts status changes. In addition to output to the STDOUT, an email can be sent out.
#  Message.abort  : This aborts the program. Likely to be an initial error.
class Message
  def initialize
  end
  def event(hash)
    if $h_host.key?(hash['ipaddr'])
      str = "%s %s %s(%s)" % [hash['time'].strftime(S_LOGDATEFORMAT), hash['status'], hash['ipaddr'], $h_host[hash['ipaddr']].comment]
    else
      str = "%s %s" % [hash['time'].strftime(S_LOGDATEFORMAT), hash['status']]
    end
    $stdout << str << "\n"
  end
  def stderr(str)
    $stderr << str << "\n"
  end
  def error(hash)
  end
  def alarm(hash)
    if $h_host.key?(hash['ipaddr'])
      str = "%s %s %s(%s)" % [hash['time'].strftime(S_LOGDATEFORMAT), hash['status'], hash['ipaddr'], $h_host[hash['ipaddr']].comment]
    else
      str = "%s %s" % [hash['time'].strftime(S_LOGDATEFORMAT), hash['status']]
    end
    $stdout << str << "\n"
    email(str)
  end
  def abort(str)
    self.stderr(str)
    exit(1)
  end
end

# HTML report class
class HTMLReport
  @@template = open('status.html', 'r') {|fp| fp.read}
  def initialize(outputpath)
    @outputpath = outputpath
    @h_htmlhost = {}
    @htmlstat = ''
    @htmlinitconf = ''
  end
  def update_host(ip)
    host = $h_host[ip]
    @h_htmlhost[ip] = "<tr><td>#{ip}</td><td>#{host.comment}</td><td class=\"#{host.status.downcase}\">#{host.status}</td></tr>\n"
  end
  def update_hosts
    @h_htmlhost = {}
    $h_host.each do |ip, host|
      @h_htmlhost[ip] = "<tr><td>#{ip}</td><td>#{host.comment}</td><td class=\"#{host.status.downcase}\">#{host.status}</td></tr>\n"
    end
  end
  def update_stat
    @htmlstat = ''
  end
  def update_initconf
    @htmlinitconf = ''
    $h_initconfig.each do |key, val|
      @htmlinitconf << "<tr><td>#{key}</td><td>#{val}</td></tr>\n"
    end
  end
  def run
    htmloutput = @@template.sub('<!-- ##SYSTEM_NAME## -->', S_SYSTEMNAME)
    htmloutput = htmloutput.sub('<!-- ##UPDATE## -->', Time.now.strftime(S_REPORTDATEFORMAT))
    htmloutput = htmloutput.sub('<!-- ##HOST## -->', @h_htmlhost.values.join)
    htmloutput = htmloutput.sub('<!-- ##STAT## -->', @htmlstat)
    htmloutput = htmloutput.sub('<!-- ##INIT_CONFIG## -->', @htmlinitconf)
    fp_report = open(@outputpath, 'w')
    fp_report.print(htmloutput)
    fp_report.close
  end
end

# Host class
#  Contain information about the host to be monitored.
#  Host.ping : Pings the host and returns status. (alive=TRUE, dead=FALSE)
#  Host.status : Returns status of the host.
#    INIT=configuring or was never up since start
#    UP=replied to the ping and is up
#    DOWN=did not reply to the ping and is assumed to be down
#  Host.comment : Returns a comment of the host.
#  Host.lastchange : Returns the time of when the host status last changed.
#  Host.lastping : Returns the time of when the host was last pinged.
class Host
  def initialize(ipaddr, comment)
    @timestatuschange = Time.now
    @status = 'INIT'
    @ipaddr = ipaddr
    @comment = comment
    $q_msg << {'time' => @timestatuschange, 'ipaddr' => @ipaddr, 'status' => @status, 'type' => 'event'}
  end
  def ping
    @timeping = Time.now
    pingstatus = Ping.pingecho(@ipaddr, $i_pingtimeout, $i_pingport)
    if pingstatus
      case @status
      when 'INIT'
        @timestatuschange = @timeping
        type = 'event'
      when 'UP'
        type = 'event'
      when 'DOWN'
        @timestatuschange = @timeping
        type = 'alarm'
      end
      @status = 'UP'
    else
      case @status
      when 'INIT'
        type = 'event'
      when 'UP'
        @timestatuschange = @timeping
        type = 'alarm'
        @status = 'DOWN'
      when 'DOWN'
        type = 'event'
      end
    end
    $q_msg << {'time' => @timeping, 'ipaddr' => @ipaddr, 'status' => @status, 'type' => type}
    pingstatus
  end
  def status
    @status
  end
  def comment
    @comment
  end
  def lastchange
    @timestatuschange
  end
  def lastping
    @timeping
  end
end


##
## Start main routine
##
$msg = Message.new

## Read configuration
$msg.stderr("CONFIG: Reading configuration...")
begin
  i = 0
  ARGF.each do |line|
    i += 1
    if /^(#.*|)$/ =~ line
      next
    elsif /^([\w]+) *= *(.+)$/ =~ line
      key, val = [$1, $2]
      $h_initconfig[key]=val
      case key
      when 'PING_TIMEOUT'
        if /^\d+$/ =~ val
          $i_pingtimeout = val.to_i
          if I_PINGTIMEOUT_MAX < $i_pingtimeout
            raise "value out of range : #{key}=#{val}"
          end
        else
          raise "wrong value : #{key}=#{val}"
        end
      when 'PING_PORT'
        if /^\d+$/ =~ val
          $i_pingport = val.to_i
          if 0 > $i_pingport or 65535 < $i_pingport
            raise "value out of range : #{key}=#{val}"
          end
        else
          raise "wrong value : #{key}=#{val}"
        end
      when 'PING_INTERVAL'
        if /^\d+$/ =~ val
          $i_pinginterval = val.to_i
          if I_PINGINTERVAL_MIN > $i_pinginterval
            raise "value out of range : #{key}=#{val}"
          end
        else
          raise "wrong value : #{key}=#{val}"
        end
      when 'PING_RETRY'
        if /^\d+$/ =~ val
          $i_pingretry = val.to_i
          if I_PINGRETRY_MAX < $i_pingretry
            raise "value out of range : #{key}=#{val}"
          end
        else
          raise "wrong value : #{key}=#{val}"
        end
      when 'SMTP_SERVER'
        if /^[A-Za-z0-9\-\.]+$/ =~ val
          $s_smtpserver = val
        else
          raise "wrong value : #{key}=#{val}"
        end
      when 'SMTP_PORT'
        if /^\d+$/ =~ val
          $i_smtpport = val.to_i
          if 0 > $i_smtpport or 65536 < $i_smtpport
            raise "value out of range : #{key}=#{val}"
          end
        else
          raise "wrong value : #{key}=#{val}"
        end
      when 'SMTP_DOMAIN'
        if /^[A-Za-z0-9\-\.]+$/ =~ val
          $s_smtpdomain = val
        else
          raise "wrong value : #{key}=#{val}"
        end
      when 'EMAIL_FROM'
        if /^[^@\s]+@[A-Za-z0-9\-\.]+$/ =~ val
          $s_emailfrom = val
        else
          raise "wrong value : #{key}=#{val}"
        end
      when 'EMAIL_ALARM'
        if /^[^@\s]+@[A-Za-z0-9\-\.]+$/ =~ val
          $a_emailalarm << val
        else
          raise "wrong value : #{key}=#{val}"
        end
      when 'ALARM_SUBJECT'
        if /^.+$/ =~ val
          $s_alarmsubject = val
        else
          raise "wrong value : #{key}=#{val}"
        end
      else
        raise 'unrecognized varialble'
      end
    elsif /^([\.\d]{7,15}) *= *(.+)$/ =~ line
      ipaddr = IPAddr.new($1)
      $h_host[ipaddr.to_s] = $2
    else
      raise 'syntax error'
    end
  end
rescue
  $msg.abort("CONFIG: Configuration error at line #{i}. (#{$!})")
end
$h_initconfig['EMAIL_ALARM'] = $a_emailalarm.join(',')
$msg.stderr("done.")

$report = HTMLReport.new($s_reportpath)
$report.update_initconf
$report.run


##
## Message handling thread
##
$msg.stderr("MSG: Starting message handler.")
#$q_msg << {'time' => Time.now, 'ipaddr' => localhost, 'status' => 'MSG: Up.', 'type' => 'event'}
Thread.start {
begin
  $q_msg << {'time' => Time.now, 'ipaddr' => 'localhost', 'status' => 'Up and running: ' + S_SYSTEMNAME, 'type' => 'event'}
  sleep 2
  loop {
    h_msg = $q_msg.pop
    eval("\$msg.#{h_msg['type']}(h_msg)")
  }
rescue
  p $!
end
}


##
## Start monitoring thread for each IP
##
$msg.stderr("MONITOR: Starting #{$h_host.length} host monitoring sessions.")
$h_host.each do |ipaddr, comment|
  $h_host[ipaddr] = Host.new(ipaddr, comment)
  Thread.start {
    loop {
      $h_host[ipaddr].ping
      sleep $i_pinginterval - (Time.now - $h_host[ipaddr].lastping)
    }
  }
end


$report.update_hosts
$report.run


##
## Put main thread to sleep
##
Thread.stop
