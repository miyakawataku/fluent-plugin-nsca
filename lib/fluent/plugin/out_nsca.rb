# -*- encoding: utf-8 -*-
# vim: et sw=2 sts=2

module Fluent

  # Fluentd output plugin to send service checks
  # to an NSCA / Nagios monitoring servers.
  class NscaOutput < Fluent::BufferedOutput
    Fluent::Plugin.register_output('nsca', self)

    #
    # Maximum bytes specified in the pack string in send_nsca library
    #

    # The maximum bytes for host names.
    MAX_HOST_NAME_BYTES = 64

    # The maximum bytes for service descriptions.
    MAX_SERVICE_DESCRIPTION_BYTES = 128

    # The maximum bytes for plugin outputs.
    MAX_PLUGIN_OUTPUT_BYTES = 512

    #
    # Return codes
    #

    # OK return code (0).
    OK = 0

    # WARNING return code (1).
    WARNING = 1

    # CRITICAL return code (2).
    CRITICAL = 2

    # UNKNOWN return code (3).
    UNKNOWN = 3

    # Mapping from the permitted return code representations
    # to the normalized return codes.
    VALID_RETURN_CODES = {
      # OK
      OK => OK, OK.to_s => OK, 'OK' => OK,

      # WARNING
      WARNING => WARNING, WARNING.to_s => WARNING, 'WARNING' => WARNING,

      # CRITICAL
      CRITICAL => CRITICAL, CRITICAL.to_s => CRITICAL, 'CRITICAL' => CRITICAL,

      # UNKNOWN
      UNKNOWN => UNKNOWN, UNKNOWN.to_s => UNKNOWN, 'UNKNOWN' => UNKNOWN
    }

    #
    # Config parameters
    #

    # The IP address or the hostname of the host running the NSCA daemon.
    config_param :server, :string, :default => 'localhost'

    # The port on which the NSCA daemon is running.
    config_param :port, :integer, :default => 5667

    # The password for authentication and encryption.
    config_param :password, :string, :default => ''

    # Host name options: default = the host name of the fluentd server.
    config_param :host_name, :string, :default => nil
    config_param :host_name_field, :string, :default => nil

    # Service description options: default=tag.
    config_param :service_description, :string, :default => nil
    config_param :service_description_field, :string, :default => nil

    # Return code options: default=UNKNOWN.
    config_param :return_code_field, :string, :default => nil
    config_param(:return_code, :default => UNKNOWN) { |return_code|
      if not VALID_RETURN_CODES.has_key?(return_code)
          raise Fluent::ConfigError,
            "invalid 'return_code': #{return_code}; 'return_code' must be" +
            " 0, 1, 2, 3, OK, WARNING, CRITICAL, or UNKNOWN"
      end
      VALID_RETURN_CODES[return_code]
    }

    # Plugin output options: default = JSON notation of the record.
    config_param :plugin_output, :string, :default => nil
    config_param :plugin_output_field, :string, :default => nil

    # Overrides a buffering option.
    config_param :flush_interval, :time, :default => 1

    # Load SendNsca module.
    private
    def initialize
      super
      require 'send_nsca'
    end

    # Read and validate the configuration.
    public
    def configure(conf)
      super
      @host_name ||= Socket.gethostname
      reject_host_name_option_exceeding_max_bytes
      reject_service_description_option_exceeding_max_bytes
      reject_plugin_output_option_exceeding_max_bytes
    end

    # Reject host_name option exceeding the max bytes.
    private
    def reject_host_name_option_exceeding_max_bytes
      if host_name_exceeds_max_bytes?(@host_name)
        raise ConfigError,
          "host_name must not exceed #{MAX_HOST_NAME_BYTES} bytes"
      end
    end

    # Reject service_description option exceeding the max bytes.
    private
    def reject_service_description_option_exceeding_max_bytes
      if service_description_exceeds_max_bytes?(@service_description)
        raise ConfigError,
          "service_description must not exceed" +
          " #{MAX_SERVICE_DESCRIPTION_BYTES} bytes"
      end
    end

    # Reject plugin_output option exceeding the max bytes.
    private
    def reject_plugin_output_option_exceeding_max_bytes
      if plugin_output_exceeds_max_bytes?(@plugin_output)
        raise ConfigError,
          "plugin_output must not exceed #{MAX_PLUGIN_OUTPUT_BYTES} bytes"
      end
    end

    # Pack the tuple (tag, time, record).
    public
    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    # Send a service check.
    public
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

    # Determines the host name.
    private
    def determine_host_name(record)
      if @host_name_field and record[@host_name_field]
        host_name = record[@host_name_field].to_s
        warn_if_host_name_exceeds_max_bytes(host_name)
        return host_name
      else
        return @host_name
      end
    end

    # Determines the service description.
    private
    def determine_service_description(tag, record)
      if @service_description_field and record[@service_description_field]
        service_description = record[@service_description_field]
        warn_if_service_description_exceeds_max_bytes(service_description)
        return service_description
      elsif @service_description
        return @service_description
      else
        warn_if_service_description_exceeds_max_bytes(tag)
        return tag
      end
    end

    # Determines the return code.
    private
    def determine_return_code(record)
      if @return_code_field and record[@return_code_field]
        return_code =  VALID_RETURN_CODES[record[@return_code_field]]
        if return_code
          return return_code
        end
        log.warn('Invalid return code.',
                 :return_code_field => @return_code_field,
                 :value => record[@return_code_field],
                 :fall_back_to => @return_code)
      end
      return @return_code
    end

    # Determines the plugin output.
    private
    def determine_plugin_output(record)
      if @plugin_output_field and record[@plugin_output_field]
        plugin_output = record[@plugin_output_field]
        warn_if_plugin_output_exceeds_max_bytes(plugin_output)
        return plugin_output
      elsif @plugin_output
        return @plugin_output
      else
        plugin_output = record.to_json
        warn_if_plugin_output_exceeds_max_bytes(plugin_output)
        return plugin_output
      end
    end

    # Log a warning if the host name exceeds the max bytes.
    private
    def warn_if_host_name_exceeds_max_bytes(host_name)
      if host_name_exceeds_max_bytes?(host_name)
        log.warn("Host name exceeds the max bytes; it will be truncated",
                 :max_host_name_bytes => MAX_HOST_NAME_BYTES,
                 :host_name => host_name)
      end
    end

    # Log a warning if the service description exceeds the max bytes.
    private
    def warn_if_service_description_exceeds_max_bytes(service_description)
      if service_description_exceeds_max_bytes?(service_description)
        log.warn(
          "Service description exceeds the max bytes; it will be truncated.",
          :max_service_description_bytes => MAX_SERVICE_DESCRIPTION_BYTES,
          :service_description => service_description)
      end
    end

    # Log a warning if the plugin output exceeds the max bytes.
    private
    def warn_if_plugin_output_exceeds_max_bytes(plugin_output)
      if plugin_output_exceeds_max_bytes?(plugin_output)
        log.warn("Plugin output exceeds the max bytes; it will be truncated.",
                :max_plugin_output_bytes => MAX_PLUGIN_OUTPUT_BYTES,
                :plugin_output => plugin_output)
      end
    end

    # Returns true if host_name exceeds the max bytes
    private
    def host_name_exceeds_max_bytes?(host_name)
      return !! host_name && host_name.bytesize > MAX_HOST_NAME_BYTES
    end

    # Returns true if service_description exceeds the max bytes
    private
    def service_description_exceeds_max_bytes?(service_description)
      return !! service_description &&
        service_description.bytesize > MAX_SERVICE_DESCRIPTION_BYTES
    end

    # Returns true if plugin_output exceeds the max bytes
    private
    def plugin_output_exceeds_max_bytes?(plugin_output)
      return !! plugin_output &&
        plugin_output.bytesize > MAX_PLUGIN_OUTPUT_BYTES
    end

  end
end
