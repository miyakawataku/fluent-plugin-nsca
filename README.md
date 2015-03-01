# fluent-plugin-nsca

[Fluentd](http://fluentd.org) output plugin to send service checks to an
[NSCA](http://exchange.nagios.org/directory/Addons/Passive-Checks/NSCA--2D-Nagios-Service-Check-Acceptor/details)
/ [Nagios](http://www.nagios.org/) monitoring server.

The plugin sends a service check to the NSCA server for each record.

## Configuration

### Example configuration

```apache
<match ddos>
  type nsca

  # Connection settings
  server monitor.example.com
  port 5667
  password aoxomoxoa

  # Payload settings

  ## The monitored host name is "web.example.com"
  host_name web.example.com

  ## The service is "ddos_detection"
  service_description ddos_detection

  ## The return code is read from the field "level"
  return_code_field level

  ## The plugin output is not specified;
  ## hence the plugin sends the JSON notation of the record.

</match>
```

### Plugin type

The type of this plugin is `nsca`.
Specify `type nsca` in the `match` section.

### Connection setting

* `server` (default is "localhost")
  * The IP address or the hostname of the host running the NSCA daemon.
* `port` (default is 5667)
  * The port on which the NSCA daemon is running.
* `password` (default is an empty string)
  * The password for authentication and encryption.

### Check payload

A service check for the NSCA server
comprises the following four fields.

* Host name
  * The name of the monitored host.
  * The corresponding property in the Nagios configuration is
    `host_name` property in a `host` definition.
  * Limited to the maximum 64 bytes.
* Service description
  * The name of the monitored service.
  * The corresponding property in the Nagios configuration is
    `service_description` property in a `service` definition.
  * Limited to the maximum 128 bytes.
* Return code
  * The severity level of the service status.
  * 0 (OK), 1 (WARNING), 2 (CRITICAL) or 3 (UNKNOWN).
* Plugin output
  * A description of the service status.
  * Limited to the maximum 512 bytes.

The destination of checks
are identified by the pair of the host name and the service description.

#### Host name

The host name is determined as below.

1. The field specified by `host_name_field` option,
   if present (highest priority)
  * If the value exceeds the maximum 64 bytes, it will be truncated.
2. or `host_name` option, if present
  * If the value exceeds the maximum 64 bytes, it causes a config error.
3. or the host name of the fluentd server (lowest priority)
  * If the value exceeds the maximum 64 bytes, it causes a config error.

For example,
assume that the fluentd server has the host name "fluent",
and the configuration file contains the section below:

```apache
<match ddos>
  type nsca
  ...snip...
  host_name_field monitee
</match>
```

When the record `{"num" => 42, "monitee" => "web.example.org"}`
is input to the tag `ddos`,
the plugin sends a service check with the host name "web.example.org".

When the record `{"num" => 42}` is input to the tag `ddos`,
the plugin sends a service check with the host name "fluent"
(the host name of the fluentd server).

#### Service description

The service description is determined as below.

1. The field specified by `service_description_field` option,
   if present (highest priority)
  * If the value exceeds the maximum 128 bytes, it will be truncated.
2. or `service_description` option, if present
  * If the value exceeds the maximum 128 bytes, it causes a config error.
3. or the tag name (lowest priority)
  * If the value exceeds the maximum 128 bytes, it will be truncated.

For example,
assume that the configuration file contains the section below:

```apache
<match ddos>
  type nsca
  ...snip...
  service_description_field monitee_service
</match>
```

When the record
`{"num" => 42, "monitee_service" => "ddos_detection"}`
is input to the tag `ddos`,
the plugin sends a service check with the service description
"ddos\_detection".

When the record
`{"num" => 42}` is input to the tag `ddos`,
the plugin sends a service check with the service description
"ddos" (the tag name).

#### Return code

The return code is determined as below.

1. The field specified by `return_code_field` option,
   if present (highest priority)
  * The values permitted for the field are integers `0`, `1`, `2`, `3`
    and strings `"0"`, `"1"`, `"2"`, `"3"`,
    `"OK"`, `"WARNING"`, `"CRITICAL"`, `"UNKNOWN"`.
  * If the field contains a value not permitted,
    the plugin falls back to `return_code` option if present,
    or to `3` (UNKNOWN).
2. or `return_code` option, if present
  * The permitted values are `0`, `1`, `2`, `3`,
    and `OK`, `WARNING`, `CRITICAL`, `UNKNOWN`.
  * If the value is invalid, it causes a config error.
3. or `3`, which means UNKNOWN (lowest priority)

For example,
assume that the configuration file contains the section below:

```apache
<match ddos>
  type nsca
  ...snip...
  return_code_field level
</match>
```

When the record
`{"num" => 42, "level" => "WARNING"}` is input to the tag `ddos`,
the plugin sends a service check with the return code `1`,
which means WARNING.

When the record
`{"num" => 42}` is input to the tag `ddos`,
the plugin sends a service check with the default return code `3`,
which means UNKNOWN.

#### Plugin output

The plugin output is determined as below.

1. The field specified by `plugin_output_field` option,
   if present (highest priority)
  * If the value exceeds the maximum 512 bytes, it will be truncated.
2. or `plugin_output` option
  * If the value exceeds the maximum 512 bytes, it causes a config error.
3. or JSON notation of the record (lowest priority)
  * If the value exceeds the maximum 512 bytes, it will be truncated.

For example,
assume that the configuration file contains the section below:

```apache
<match ddos>
  type nsca
  ...snip...
  plugin_output_field status
</match>
```

When the record
`{"num" => 42, "status" => "DDOS detected"}` is input to the tag `ddos`,
the plugin sends a service check with the plugin output "DDOS detected".

When the record
`{"num" => 42}` is input to the tag `ddos`,
the plugin sends a service check with the plugin output '{"num":42}'.

### Buffering

The default value of `flush_interval` option is set to 1 second.
It means that service checks are delayed at most 1 second
before being sent.

Except for `flush_interval`,
the plugin uses default options
for buffered output plugins (defined in Fluent::BufferedOutput class).

You can override buffering options in the configuration.
For example:

```apache
<match ddos>
  type nsca
  ...snip...
  buffer_type file
  buffer_path /var/lib/td-agent/buffer/ddos
  flush_interval 0.1
  try_flush_interval 0.1
</match>
```

## Use case: "too many server errors" alert

### Situation

You have

* "web" server (192.168.42.123) which runs Apache HTTP Server and Fluentd, and
* "monitor" server (192.168.42.210) which runs Nagios and NSCA.

You want to be notified when Apache responds too many server errors,
for example 5 errors per minute as WARNING,
and 50 errors per minute as CRITICAL.

### Nagios configuration on "monitor" server

Create web.cfg file shown as below,
under the Nagios configuration direcotry.

```
# File: web.cfg

# "web" server definition
define host {
  use generic-host
  host_name web
  alias web
  address 192.168.42.123
}

# Server errors service definition
define service {
  use generic-service
  name server_errors
  active_checks_enabled 0
  passive_checks_enabled 1
  flap_detection_enabled 0
  max_check_attempts 1
  check_command check_dummy!0
}

# Delete this section if check_dummy command is defined elsewhere
define command {
  command_name check_dummy
  command_line $USER1$/check_dummy $ARG1$
}
```

### Fluentd configuration on "web" server

This setting utilizes [fluent-plugin-datacounter](
https://github.com/tagomoris/fluent-plugin-datacounter),
[fluent-plugin-record-reformer](
https://github.com/sonots/fluent-plugin-record-reformer),
and of course `fluent-plugin-nsca`.
So, first of all, install those gems.

Next, add these lines to the Fluentd configuration file.

```apache
# Parse Apache access log
<source>
  type tail
  tag access
  format apache2

  # The paths vary by setup
  path /var/log/httpd/access_log
  pos_file /var/log/fluentd/httpd-access_log.pos
</source>

# Count 5xx errors per minute
<match access>
  type datacounter
  tag count.access
  unit minute
  aggregate all
  count_key code
  pattern1 error ^5\d\d$
</match>

# Calculate the severity level
<match count.access>
  type record_reformer
  tag server_errors
  enable_ruby true
  <record>
    level ${error_count < 5 ? 'OK' : error_count < 50 ? 'WARNING' : 'CRITICAL'}
  </record>
</match>

# Send checks to NSCA
<match server_errors>
  type nsca
  server 192.168.42.210
  port 5667
  # Empty password!

  host_name web
  service_description server_errors
  return_code_field level
</match>
```

You can use `record_transformer` filter
instead of `fluent-plugin-record-reformer`
on Fluentd 0.12.0 and above.

## Installation

1. Install fluent-plugin-nsca gem from rubygems.org.
2. Add `match` sections to your fluentd configuration file.

## Contributing

Create an [issue](https://github.com/miyakawataku/fluent-plugin-nsca/issues).

Or ask questions on Twitter to
[@miyakawa\_taku](https://twitter.com/miyakawa_taku).

Or submit a pull request as follows:

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
