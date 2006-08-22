#!/usr/bin/ruby
#
# eznemo.rb - A simple host monitoring with TCP ping.
# ver.0.7beta (2006-08-21)
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
S_SYSTEMNAME = 'EzNemo ver.0.7beta - (c) 2006 CYANandBLUE'
I_PINGTIMEOUT_MAX = 10
I_PINGINTERVAL_MIN = 60
I_PINGRETRY_MAX = 10


##
## Default setting (variables will be reset by configuration)
##
$i_pingtcpport = 7
$i_pingtimeout = 1
$i_pinginterval = 300
$i_pingretry = 2
$s_smtpserver = '127.0.0.1'
$i_smtpport = 25
$s_smtpdomain = ''
$s_emailfrom = ''
$a_emailalarm = []
$s_alarmsubject = 'EzNemo ALARM'

# $q_msg = {'time' => , 'ipaddr' => , 'status' => , 'type' => , }
$q_msg = Queue.new
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
#  Message.event : Any action can be an event if the hosts status does not change. A line will output to the STDOUT.
#  Message.error : Whenever something unexpected happens. A line will output to the STDERR.
#  Message.alarm : Whenever the hosts status changes. In addition to output to the STDOUT, an email can be sent out.
#  Message.abort : This aborts the program. Likely to be an initial error.
class Message
  def initialize
  end
  def event(hash)
    if $h_host.key?(hash['ipaddr'])
      str = "%s %s %s(%s)" % [hash['time'].strftime("%Y-%m-%dT%H:%M:%S%Z"), hash['status'], hash['ipaddr'], $h_host[hash['ipaddr']].comment]
    else
      str = "%s %s" % [hash['time'].strftime("%Y-%m-%dT%H:%M:%S%Z"), hash['status']]
    end
    $stdout << str << "\n"
  end
  def error(hash)
  end
  def alarm(hash)
    if $h_host.key?(hash['ipaddr'])
      str = "%s %s %s(%s)" % [hash['time'].strftime("%Y-%m-%dT%H:%M:%S%Z"), hash['status'], hash['ipaddr'], $h_host[hash['ipaddr']].comment]
    else
      str = "%s %s" % [hash['time'].strftime("%Y-%m-%dT%H:%M:%S%Z"), hash['status']]
    end
    $stdout << str << "\n"
    email(str)
  end
  def abort(hash)
    if $h_host.key?(hash['ipaddr'])
      str = "%f %s %s(%s)" % [hash['time'].to_f, hash['status'], hash['ipaddr'], $h_host[hash['ipaddr']].comment]
    else
      str = "%f %s" % [hash['time'].to_f, hash['status']]
    end
    $stderr << "\n" << str << "\n"
    exit(1)
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
    pingstatus = Ping.pingecho(@ipaddr, $i_pingtimeout, $i_pingtcpport)
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
$stderr << "CONFIG: Reading configuration... "
begin
  i = 0
  ARGF.each do |line|
    i += 1
    if line =~ /^(#.*|)$/
      next
    elsif line =~ /^([\w]+) *= *(.+)$/
      key, val = [$1, $2]
      case key
      when 'PING_TIMEOUT'
        if val =~ /^\d+$/
          $i_pingtimeout = val.to_i
          if I_PINGTIMEOUT_MAX < $i_pingtimeout
            raise 'value out of range'
          end
        else
          raise 'wrong value'
        end
      when 'PING_INTERVAL'
        if val =~ /^\d+$/
          $i_pinginterval = val.to_i
          if I_PINGINTERVAL_MIN > $i_pinginterval
            raise 'value out of range'
          end
        else
          raise 'wrong value'
        end
      when 'PING_RETRY'
        if val =~ /^\d+$/
          $i_pingretry = val.to_i
          if I_PINGRETRY_MAX < $i_pingretry
            raise 'value out of range'
          end
        else
          raise 'wrong value'
        end
      when 'SMTP_SERVER'
        if val =~ /^[A-Za-z0-9\-\.]+$/
          $s_smtpserver = val
        else
          raise 'wrong value'
        end
      when 'SMTP_PORT'
        if val =~ /^\d+$/
          $i_smtpport = val.to_i
          if 0 > $i_smtpport or 65536 < $i_smtpport
            raise 'value out of range'
          end
        else
          raise 'wrong value'
        end
      when 'SMTP_DOMAIN'
        if val =~ /^[A-Za-z0-9\-\.]+$/
          $s_smtpdomain = val
        else
          raise 'wrong value'
        end
      when 'EMAIL_FROM'
        if val =~ /^[^@\s]+@[A-Za-z0-9\-\.]+$/
          $s_emailfrom = val
        else
          raise 'wrong value'
        end
      when 'EMAIL_ALARM'
        if val =~ /^[^@\s]+@[A-Za-z0-9\-\.]+$/
          $a_emailalarm << val
        else
          raise 'wrong value'
        end
      when 'ALARM_SUBJECT'
        if val =~ /^.+$/
          $s_alarmsubject << val
        else
          raise 'wrong value'
        end
      else
        raise 'unrecognized varialble'
      end
    elsif line =~ /^([\.\d]{7,15}) *= *(.+)$/
      ipaddr = IPAddr.new($1)
      $h_host[ipaddr.to_s] = $2
    else
      raise 'syntax error'
    end
  end
rescue
  $msg.abort("CONFIG: Configuration error at line #{i}. (#{$!})")
end
$stderr << "done.\n"


##
## Message handling thread
##
$stderr << "MSG: Starting message handler.\n"
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
$stderr << "MONITOR: Starting #{$h_host.length} host monitoring sessions.\n"
$h_host.each do |ipaddr, comment|
  $h_host[ipaddr] = Host.new(ipaddr, comment)
  Thread.start {
    loop {
      $h_host[ipaddr].ping
      sleep $i_pinginterval - (Time.now - $h_host[ipaddr].lastping)
    }
  }
end


##
## Put main thread to sleep
##
Thread.stop
