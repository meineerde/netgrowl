# encoding: utf-8
$KCODE = "UTF-8"

require 'socket'
require 'netgrowl/netgrowl'

module Growl
  GROWL_UDP_PORT = 9887

  class GrowlError < StandardError; end

  VERSION = [0, 1, 0]
  def self.version
    VERSION.join(".")
  end

  def notify(message=nil, options={}, &block)
    options = options.merge(:message => message) if message
    Growl.new(options, &block).notify
  end
  module_function :notify

  def register(register_args, options={}, &block)
    Growl.new(options, &block).register_identifiers(register_args)
  end
  module_function :register

  ##
  # Return an instance of Growl::Base

  def self.new *args, &block
    Base.new(*args, &block)
  end

  class Base
    ##
    # Initialize with optional +block+, which is then
    # instance evaled or yielded depending on the blocks arity.

    def initialize(args = {}, &block)
      if block_given?
        if block.arity > 0
          yield self
        else
          self.instance_eval(&block)
        end
      else
        args.each do |key, value|
          send :"#{key}=", value
        end
      end
    end

    ##
    # Return array of available switch symbols.

    def self.switches
      @switches
    end

    def notify
      raise GrowlError.new("Message required") unless message

      p = Netgrowl::GrowlNotificationPacket.new(
        :notification => identifier,
        :title => title,
        :description => message,
        :application => application,
        :priority => priority,
        :sticky => sticky?,
        :password => password
      )
      socket_send(p.payload)
    end

    ##
    # Register a notification type

    def register_identifiers(args=[])
      register = Netgrowl::GrowlRegistrationPacket.new(
        :application => application,
        :password => password
      )

      args = [args] unless args.is_a? Array
      args.each do |arg|
        if arg.is_a?(Hash)
          identifier = arg[:identifier]
          default = arg.include?(:default) ? !!arg[:default] : true
        else
          identifier = arg
          default = true
        end

        register.add_notification(identifier, default)
      end
      socket_send(register.payload)
    end

    def socket_send(payload)
      addr = [host || 'localhost', port || Growl::GROWL_UDP_PORT]
      socket = UDPSocket.new

      socket.send(payload, 0, *addr)
    end

  protected
    ##
    # Define a switch +name+.
    #
    # === examples
    #
    # switch :sticky
    #
    # @growl.sticky! # => true
    # @growl.sticky? # => true
    # @growl.sticky = false # => false
    # @growl.sticky? # => false
    #

    def self.switch name
      ivar = :"@#{name}"
      (@switches ||= []) << name
      attr_accessor :"#{name}"
      define_method(:"#{name}?") { !!instance_variable_get(ivar) }
      define_method(:"#{name}!") { instance_variable_set(ivar, true) }
    end

    # The name of the application. Default: growlnotify
    switch :application

    # Notification type. This needs to be registered first!
    switch :identifier

    # The title of the notification. Defauklt: Title
    switch :title
    # The body text of the notification
    switch :message

    # sticky notification? Default: false
    switch :sticky

    # Priority of notification. Integer between -2 and 2. Default: 0
    switch :priority

    # Host to send the notification to. Defaulkt: localhost
    switch :host

    # Password to authenticate against Growl. Default: empty
    switch :password

    # UDP Port to communicate to. Default: 9887
    switch :port

    # Hash algorithm to verify messages with. One of MD5, SHA256, or NONE
    switch :auth
  end
end
