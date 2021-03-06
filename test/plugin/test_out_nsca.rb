# -*- encoding: utf-8 -*-
# vim: et sw=2 sts=2

require 'helper'
require 'send_nsca'

# Test class for Fluent::NscaOutput
class NscaOutputTest < Test::Unit::TestCase

  # Sets up the test env and the stub
  def setup
    Fluent::Test.setup

    # Stub NscaConnection
    # whose send_nsca method returns the connection info and the check payload
    # instead of sending the service check.
    stub.proxy(SendNsca::NscaConnection).new { |obj|
      stub(obj).send_nsca {
        obj.instance_eval {
          [@nscahost, @port, @password,
           @hostname, @service, @return_code, @status]
        }
      }
    }
  end

  # Common settings
  CONFIG = %[
    server monitor.example.com
    port 4242
    password aoxomoxoa
  ]

  # Returns a driver of the plugin
  def create_driver(conf = CONFIG, tag='test')
    driver = Fluent::Test::BufferedOutputTestDriver.new(Fluent::NscaOutput, tag)
    driver.configure(conf)
  end

  # Connection settings are read
  def test_connection_settings
    driver = create_driver(CONFIG)
    assert_equal 'monitor.example.com', driver.instance.instance_eval{ @server }
    assert_equal 4242, driver.instance.instance_eval{ @port }
    assert_equal 'aoxomoxoa', driver.instance.instance_eval{ @password }
  end

  # Default values are set to connection values
  def test_default_connection_settings
    driver = create_driver('')
    assert_equal 'localhost', driver.instance.instance_eval{ @server }
    assert_equal 5667, driver.instance.instance_eval{ @port }
    assert_equal '', driver.instance.instance_eval{ @password }
  end

  # Reject host_name option exceeding the max bytes
  def test_reject_host_name_option_exceeding_max_bytes
    max_bytes = Fluent::NscaOutput::MAX_HOST_NAME_BYTES
    config = %[
      #{CONFIG}
      host_name #{'x' * (max_bytes + 1)}
    ]
    assert_raise(Fluent::ConfigError) {
      create_driver(config)
    }
  end

  # Decide if host name exceeds the max bytes
  def test_host_name_exceeds_max_bytes()
    max_bytes = Fluent::NscaOutput::MAX_HOST_NAME_BYTES
    driver = create_driver('')

    max_bytes_host_name = 'x' * max_bytes
    assert_equal false, driver.instance.instance_eval{
      host_name_exceeds_max_bytes?(max_bytes_host_name)
    }

    invalid_host_name = 'x' * (max_bytes + 1)
    assert_equal true, driver.instance.instance_eval{
      host_name_exceeds_max_bytes?(invalid_host_name)
    }

    assert_equal false, driver.instance.instance_eval{
      host_name_exceeds_max_bytes?(nil)
    }
  end

  # Reject service_description option exceeding the max bytes
  def test_reject_service_description_option_exceeding_max_bytes
    max_bytes = Fluent::NscaOutput::MAX_SERVICE_DESCRIPTION_BYTES
    config = %[
      #{CONFIG}
      service_description #{'x' * (max_bytes + 1)}
    ]
    assert_raise(Fluent::ConfigError) {
      create_driver(config)
    }
  end

  # Decide if service description exceeds the max bytes
  def test_service_description_exceeds_max_bytes()
    max_bytes = Fluent::NscaOutput::MAX_SERVICE_DESCRIPTION_BYTES
    driver = create_driver('')

    max_bytes_service = 'x' * max_bytes
    assert_equal false, driver.instance.instance_eval{
      service_description_exceeds_max_bytes?(max_bytes_service)
    }

    invalid_service = 'x' * (max_bytes + 1)
    assert_equal true, driver.instance.instance_eval{
      service_description_exceeds_max_bytes?(invalid_service)
    }

    assert_equal false, driver.instance.instance_eval{
      service_description_exceeds_max_bytes?(nil)
    }
  end

  # Reject plugin_output option exceeding the max bytes
  def test_reject_plugin_output_exceeding_max_bytes
    max_bytes = Fluent::NscaOutput::MAX_PLUGIN_OUTPUT_BYTES
    config = %[
      #{CONFIG}
      plugin_output #{'x' * (max_bytes + 1)}
    ]
    assert_raise(Fluent::ConfigError) {
      create_driver(config)
    }
  end

  # Decide if plugin output exceeds the max bytes
  def test_plugin_output_exceeds_max_bytes()
    max_bytes = Fluent::NscaOutput::MAX_PLUGIN_OUTPUT_BYTES
    driver = create_driver('')

    max_bytes_plugin_output = 'x' * max_bytes
    assert_equal false, driver.instance.instance_eval{
      plugin_output_exceeds_max_bytes?(max_bytes_plugin_output)
    }

    invalid_plugin_output = 'x' * (max_bytes + 1)
    assert_equal true, driver.instance.instance_eval{
      plugin_output_exceeds_max_bytes?(invalid_plugin_output)
    }

    assert_equal false, driver.instance.instance_eval{
      plugin_output_exceeds_max_bytes?(nil)
    }
  end

  # Rejects invalid return codes
  def test_reject_invalid_return_codes
    config = %[
      #{CONFIG}
      return_code invalid_return_code
    ]
    message = "invalid 'return_code': invalid_return_code;" +
      " 'return_code' must be 0, 1, 2, 3," +
      " OK, WARNING, CRITICAL, or UNKNOWN"
    assert_raise(Fluent::ConfigError, message) {
      create_driver(config)
    }
  end

  # flush_interval is set to 1
  def test_flush_interval
    driver = create_driver('')
    assert_equal 1, driver.instance.instance_eval { @flush_interval }
  end

  # Format to MessagePack(tag, time, record)
  def test_format
    driver = create_driver('', 'ddos')
    time = Time.parse('2015-01-03 12:34:56 UTC').to_i
    driver.emit({"name" => "Stephen"}, time)
    driver.emit({"name" => "Aggi"}, time)
    driver.expect_format(['ddos', time, {"name" => "Stephen"}].to_msgpack)
    driver.expect_format(['ddos', time, {"name" => "Aggi"}].to_msgpack)
    driver.run
  end

  # Sends a service check with constant values
  def test_write_constant_values
    config = %[
      #{CONFIG}
      host_name web.example.org
      service_description ddos_monitor
      return_code 2
      plugin_output possible attacks
    ]
    driver = create_driver(config, 'ddos')
    time = Time.parse('2015-01-03 12:34:56 UTC').to_i
    driver.emit({"name" => "Stephen"}, time)
    output = driver.run
    expected = ['monitor.example.com', 4242, 'aoxomoxoa',
                'web.example.org', 'ddos_monitor', 2, 'possible attacks']
    assert_equal [expected], output
  end

  # Sends a service check with host_name and host_name_field
  def test_write_check_with_host_name_and_host_name_field
    config = %[
      #{CONFIG}
      host_name_field host
      host_name fallback.example.org

      service_description ddos_monitor
      return_code 2
      plugin_output possible attacks
    ]
    driver = create_driver(config, 'ddos')
    time = Time.parse('2015-01-03 12:34:56 UTC').to_i
    driver.emit({"name" => "Stephen", "host" => "app.example.org"}, time)
    driver.emit({"name" => "Aggi"}, time)
    output = driver.run
    expected1 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'app.example.org', 'ddos_monitor', 2, 'possible attacks']
    expected2 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'fallback.example.org', 'ddos_monitor', 2, 'possible attacks']
    assert_equal [expected1, expected2], output
  end

  # Sends a service check with host_name_field
  def test_write_check_with_host_name_field
    config = %[
      #{CONFIG}
      host_name_field host

      service_description ddos_monitor
      return_code 2
      plugin_output possible attacks
    ]
    driver = create_driver(config, 'ddos')
    time = Time.parse('2015-01-03 12:34:56 UTC').to_i
    driver.emit({"name" => "Stephen", "host" => "app.example.org"}, time)
    driver.emit({"name" => "Aggi"}, time)
    output = driver.run
    require 'socket'
    expected1 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'app.example.org', 'ddos_monitor', 2, 'possible attacks']
    expected2 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 Socket.gethostname, 'ddos_monitor', 2, 'possible attacks']
    assert_equal [expected1, expected2], output
  end

  # Sends a service check with service_description and service_description_field
  def test_write_check_with_service_description_and_service_description_field
    config = %[
      #{CONFIG}
      service_description ddos_detection
      service_description_field service

      host_name web.example.org
      return_code 2
      plugin_output possible attacks
    ]
    driver = create_driver(config, 'ddos')
    time = Time.parse('2015-01-03 12:34:56 UTC').to_i
    driver.emit({"name" => "Stephen", "service" => "possible_ddos"})
    driver.emit({"name" => "Aggi"})
    output = driver.run
    expected1 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'web.example.org', 'possible_ddos', 2, 'possible attacks']
    expected2 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'web.example.org', 'ddos_detection', 2, 'possible attacks']
    assert_equal [expected1, expected2], output
  end

  # Sends a service check with service_description_field
  def test_write_check_with_service_description_field
    config = %[
      #{CONFIG}
      service_description_field service

      host_name web.example.org
      return_code 2
      plugin_output possible attacks
    ]
    driver = create_driver(config, 'ddos')
    time = Time.parse('2015-01-03 12:34:56 UTC').to_i
    driver.emit({"name" => "Stephen", "service" => "possible_ddos"})
    driver.emit({"name" => "Aggi"})
    output = driver.run
    expected1 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'web.example.org', 'possible_ddos', 2, 'possible attacks']
    expected2 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'web.example.org', 'ddos', 2, 'possible attacks']
    assert_equal [expected1, expected2], output
  end

  # Sends a service check with return_code and return_code_field
  def test_write_check_with_return_code_and_return_code_field
    config = %[
      #{CONFIG}
      return_code OK
      return_code_field retcode

      host_name web.example.org
      service_description ddos_monitor
      plugin_output possible attacks
    ]
    driver = create_driver(config, 'ddos')
    time = Time.parse('2015-01-03 12:34:56 UTC').to_i
    driver.emit({"name" => "Stephen", "retcode" => "UNKNOWN"})
    driver.emit({"name" => "Aggi", "retcode" => "2"})
    driver.emit({"name" => "Katrina", "retcode" => 1})
    driver.emit({"name" => "Brian", "retcode" => "invalid-value"})
    driver.emit({"name" => "Martin"})
    output = driver.run
    expected1 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'web.example.org', 'ddos_monitor', 3, 'possible attacks']
    expected2 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'web.example.org', 'ddos_monitor', 2, 'possible attacks']
    expected3 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'web.example.org', 'ddos_monitor', 1, 'possible attacks']
    expected4 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'web.example.org', 'ddos_monitor', 0, 'possible attacks']
    expected5 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'web.example.org', 'ddos_monitor', 0, 'possible attacks']
    assert_equal [expected1, expected2, expected3, expected4, expected5], output
  end

  # Sends a service check with return_code_field
  def test_write_check_with_return_code_field
    config = %[
      #{CONFIG}
      return_code_field retcode

      host_name web.example.org
      service_description ddos_monitor
      plugin_output possible attacks
    ]
    driver = create_driver(config, 'ddos')
    time = Time.parse('2015-01-03 12:34:56 UTC').to_i
    driver.emit({"name" => "Stephen", "retcode" => "OK"})
    driver.emit({"name" => "Aggi", "retcode" => "1"})
    driver.emit({"name" => "Katrina", "retcode" => 2})
    driver.emit({"name" => "Brian", "retcode" => "invalid-value"})
    driver.emit({"name" => "Martin"})
    output = driver.run
    expected1 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'web.example.org', 'ddos_monitor', 0, 'possible attacks']
    expected2 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'web.example.org', 'ddos_monitor', 1, 'possible attacks']
    expected3 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'web.example.org', 'ddos_monitor', 2, 'possible attacks']
    expected4 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'web.example.org', 'ddos_monitor', 3, 'possible attacks']
    expected5 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'web.example.org', 'ddos_monitor', 3, 'possible attacks']
    assert_equal [expected1, expected2, expected3, expected4, expected5], output
  end

  # Sends a service check with plugin_output and plugin_output_field
  def test_write_check_with_plugin_output_and_plugin_output_field
    config = %[
      #{CONFIG}
      plugin_output DDOS detected
      plugin_output_field status

      host_name web.example.org
      service_description ddos_monitor
      return_code 2
    ]
    driver = create_driver(config, 'ddos')
    time = Time.parse('2015-01-03 12:34:56 UTC').to_i
    driver.emit({"name" => "Stephen", "status" => "Possible DDOS detected"})
    driver.emit({"name" => "Aggi"})
    output = driver.run
    expected1 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'web.example.org', 'ddos_monitor', 2, 'Possible DDOS detected']
    expected2 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'web.example.org', 'ddos_monitor', 2, 'DDOS detected']
    assert_equal [expected1, expected2], output
  end

  # Sends a service check with plugin_output_field
  def test_write_check_with_plugin_output_field
    config = %[
      #{CONFIG}
      plugin_output_field status

      host_name web.example.org
      service_description ddos_monitor
      return_code 2
    ]
    driver = create_driver(config, 'ddos')
    time = Time.parse('2015-01-03 12:34:56 UTC').to_i
    driver.emit({"name" => "Stephen", "status" => "Possible DDOS detected"})
    driver.emit({"name" => "Aggi"})
    output = driver.run
    expected1 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'web.example.org', 'ddos_monitor', 2, 'Possible DDOS detected']
    expected2 = ['monitor.example.com', 4242, 'aoxomoxoa',
                 'web.example.org', 'ddos_monitor', 2, '{"name":"Aggi"}']
    assert_equal [expected1, expected2], output
  end
end
