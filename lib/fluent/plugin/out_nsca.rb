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

    # Host name options: default=`hostname`.chomp
    config_param :host_name, :string, :default => nil
    config_param :host_name_field, :string, :default => nil

    # Service description options: default=tag
    config_param :service_description, :string, :default => nil
    config_param :service_description_field, :string, :default => nil

    # Return code options: default=3 (UNKNOWN)
    config_param :return_code_field, :string, :default => nil
    config_param(:return_code, :default => 3) { |return_code|
      if not @@valid_return_codes.has_key?(return_code)
          raise Fluent::ConfigError,
            "invalid 'return_code': #{return_code}; 'return_code' must be" +
            "0, 1, 2, 3, OK, WARNING, CRITICAL, or UNKNOWN"
      end
      @@valid_return_codes[return_code]
    }
    @@valid_return_codes = {
      0 => 0, 1 => 1, 2 => 2, 3 => 3,
      '0' => 0, '1' => 1, '2' => 2, '3' => 3,
      'OK' => 0, 'WARNING' => 1, 'CRITICAL' => 2, 'UNKNOWN' => 3
    }

    # Plugin output options: default = JSON notation of the record
    config_param :plugin_output, :string, :default => nil
    config_param :plugin_output_field, :string, :default => nil


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
          :service => determine_service_description(tag, record),
          :return_code => determine_return_code(record),
          :status => determine_plugin_output(record)
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

    private
    def determine_service_description(tag, record)
      if @service_description_field and record[@service_description_field]
        return record[@service_description_field]
      elsif @service_description
        return @service_description
      else
        return tag
      end
    end

    private
    def determine_return_code(record)
      if @return_code_field and record[@return_code_field]
        return_code =  @@valid_return_codes[record[@return_code_field]]
        if return_code
          return return_code
        end
        log.warn('Invalid return code', :return_code_field => @return_code_field, :value => record[@return_code_field])
      end
      return @return_code
    end

    private
    def determine_plugin_output(record)
      if @plugin_output_field and record[@plugin_output_field]
        return record[@plugin_output_field]
      elsif @plugin_output
        return @plugin_output
      else
        return record.to_json
      end
    end
  end
end
