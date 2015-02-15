# -*- encoding: utf-8 -*-
# vim: et sw=2 sts=2

require 'helper'
require 'send_nsca'

class NscaOutputTest < Test::Unit::TestCase
  include RR::Adapters::TestUnit

  def setup
    Fluent::Test.setup
    stub.proxy(SendNsca::NscaConnection).new { |obj|
      stub(obj).send_nsca {
        obj.instance_eval {
          [@nscahost, @port, @password, @hostname, @service, @return_code, @status]
        }
      }
    }
  end

  CONFIG = %[
    server monitor.example.com
    port 4242
    password aoxomoxoa
  ]

  def create_driver(conf = CONFIG, tag='test')
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::NscaOutput, tag).configure(conf)
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
    assert_equal [['monitor.example.com', 4242, 'aoxomoxoa', 'web.example.org', 'ddos_monitor', 2, 'possible attacks']], output
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
    expected_first = [
      'monitor.example.com', 4242, 'aoxomoxoa', 'app.example.org', 'ddos_monitor', 2, 'possible attacks'
    ]
    expected_second = [
      'monitor.example.com', 4242, 'aoxomoxoa', 'fallback.example.org', 'ddos_monitor', 2, 'possible attacks'
    ]
    assert_equal [expected_first, expected_second], output
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
    expected_first = [
      'monitor.example.com', 4242, 'aoxomoxoa', 'app.example.org', 'ddos_monitor', 2, 'possible attacks'
    ]
    expected_second = [
      'monitor.example.com', 4242, 'aoxomoxoa', `hostname`.chomp, 'ddos_monitor', 2, 'possible attacks'
    ]
    assert_equal [expected_first, expected_second], output
  end
end
