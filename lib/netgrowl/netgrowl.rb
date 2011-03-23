# encoding: utf-8
$KCODE = "UTF-8"

require 'digest'
module Netgrowl
  GROWL_PROTOCOL_VERSION = 1
  GROWL_TYPE_REGISTRATION = 0
  GROWL_TYPE_NOTIFICATION = 1

  def self.digest(payload, algorithm='MD5')
    case algorithm.downcase
    when 'md5': Digest::MD5.digest(payload)
    when 'sha256': Digest::SHA256.digest(payload)
    when 'none': nil
    else
      raise ArgumentError("Algorithm needs to be one of MD5, SHA1, or NONE.")
    end
  end


  class GrowlRegistrationPacket
    # Builds a Growl Network Registration packet.
    # Defaults to emulating the command-line growlnotify utility.

    def initialize(args={})
      @application = args[:application] || 'growlnotify'
      @password = args[:password]
      @auth = args[:auth] || 'MD5'

      @notifications = []
      @default = [] # array of indexes into notifications
    end

    def add_notification(notification="Command-Line Growl Notification", default =true)
      # Adds a notification type and sets whether it is enabled on the GUI
      @notifications << notification
      @default << (@notifications.length-1) if default
    end

    def payload
      # Returns the packet payload.
      data = [
        GROWL_PROTOCOL_VERSION,
        registration_type(@auth),
        @application.length
      ].pack('CCn')
      data += [
        @notifications.length,
        @default.length
      ].pack('CC')
      data += @application

      @notifications.each do |notification|
        data += [notification.length].pack('n')
        data += notification
      end

      @default.each { |d| data += [d].pack('C') }

      checksum = data
      checksum += @password if @password
      data += Netgrowl.digest(checksum, @auth)
    end

  protected
    def registration_type(algorithm)
      case algorithm.downcase
      when 'md5': 0
      when 'sha256': 2
      when 'none': 4
      else
        raise ArgumentError("Algorithm needs to be one of MD5, SHA1, or NONE.")
      end
    end
  end

  class GrowlNotificationPacket
    # Builds a Growl Network Notification packet.
    # Defaults to emulating the command-line growlnotify utility.

    def initialize(args={})
      attrs = []
      attrs << @notification = (args[:notification] || 'Command-Line Growl Notification')
      attrs << @title = (args[:title] || 'Title')
      attrs << @description = (args[:description] || 'Description')
      attrs << @application = (args[:application] || 'growlnotify')
      priority = args[:priority] || 0
      sticky = !!args[:sticky]
      password = args[:password]
      auth = args[:auth] || 'MD5'

      flags = (priority & 0x07) * 2
      flags |= 0x08 if priority < 0
      flags |= 0x0100 if sticky

      @data = [
        GROWL_PROTOCOL_VERSION,
        notification_type(auth),
        flags,
        *(attrs.collect(&:length))
      ].pack('CCn'+ 'n'*attrs.length)
      @data += attrs.join

      checksum = @data
      checksum += password if password
      @data += Netgrowl.digest(checksum, auth)
    end

    def payload
      # Returns the packet payload.
      @data
    end

  protected
    def notification_type(algorithm)
      case algorithm.downcase
      when 'md5': 1
      when 'sha256': 3
      when 'none': 5
      else
        raise ArgumentError("Algorithm needs to be one of MD5, SHA1, or NONE.")
      end
    end

  end
end


# GROWL_UDP_PORT = 9887
#
# puts "Starting Unit Test"
# puts " - please make sure Growl is listening for network notifications"
# addr = ["localhost", GROWL_UDP_PORT]
# s = UDPSocket.new
#
# puts "Assembling registration packet like growlnotify's (no password)"
# p = Netgrowl::GrowlRegistrationPacket.new
# p.add_notification("foo")
# puts "Sending registration packet"
# s.send(p.payload(), 0, *addr)
#
# puts "Assembling standard notification packet"
# p = Netgrowl::GrowlNotificationPacket.new
# puts "Sending standard notification packet"
# s.send(p.payload(), 0, *addr)
#
# puts "Assembling priority -2 (Very Low) notification packet"
# p = Netgrowl::GrowlNotificationPacket.new(:priority => -2, :notification => "foo", :description=> "Hello There")
# puts "Sending priority -2 notification packet"
# s.send(p.payload(), 0, *addr)
#
# puts "Assembling priority 2 (Very High) sticky notification packet"
# p = Netgrowl::GrowlNotificationPacket.new(:priority => 2, :sticky => true)
# puts "Sending priority 2 (Very High) sticky notification packet"
# s.send(p.payload(), 0, *addr)
# s.close
# print "Done."