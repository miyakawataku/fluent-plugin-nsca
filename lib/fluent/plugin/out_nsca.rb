# -*- encoding: utf-8 -*-
# vim: et sw=2 sts=2

module Fluent
  class NscaOutput < Fluent::BufferedOutput
    Fluent::Plugin.register_output('nsca', self)

    # The IP address or the hostname of the host running the NSCA daemon.
    config_param :server, :string, :default => 'localhost'

    # The port on which the NSCA daemon is running.
    config_param :port, :integer, :default => 5667

    # The password for authentication and encryption.
    config_param :password, :string, :default => ''

    config_param :host_name, :string, :default => nil
    config_param :host_name_field, :string, :default => nil

    config_param :service_description, :string, :default => nil
    config_param :return_code, :string, :default => nil
    config_param :plugin_output, :string, :default => nil

    def initialize
      require 'send_nsca'
    end

    def configure(conf)
      super
      @host_name ||= `hostname`.chomp
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      results = []
      chunk.msgpack_each { |(tag, time, record)|
        nsca_check = SendNsca::NscaConnection.new({
          :nscahost => @server,
          :port => @port,
          :password => @password,
          :hostname => determine_host_name(record),
          :service => @service_description,
          :return_code => @return_code.to_i,
          :status => @plugin_output
        })
        results.push(nsca_check.send_nsca)
      }

      # Returns the results of send_nsca for tests
      return results
    end

    private
    def determine_host_name(record)
      if @host_name_field and record[@host_name_field]
        return record[@host_name_field].to_s
      else
        return @host_name
      end
    end
  end
end
