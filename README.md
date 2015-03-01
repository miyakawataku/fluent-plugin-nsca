# fluent-plugin-nsca

[Fluentd](http://fluentd.org) output plugin to send service checks to an
[NSCA](http://exchange.nagios.org/directory/Addons/Passive-Checks/NSCA--2D-Nagios-Service-Check-Acceptor/details)
/ [Nagios](http://www.nagios.org/) monitoring server.

The plugin sends a service check to the NSCA server for each record.

## Configuration

### Examples

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

  ## The return code is read from the field "severity"
  return_code_field severity

  ## The plugin output is not specified;
  ## hence the plugin sends the JSON notation of the record.

</match>
```

### Plugin type

The type of this plugin is `nsca`.
Specify `type nsca` in the `match` section.

### Connection

* `server` (default is "localhost")
  * The IP address or the hostname of the host running the NSCA daemon.
* `port` (default is 5667)
  * The port on which the NSCA daemon is running.
* `password` (default is an empty string)
  * The password for authentication and encryption.

### Payload

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
  * The severity of the service status.
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
2. Or `host_name` option, if present
  * If the value exceeds the maximum 64 bytes, it causes a config error.
3. Or the host name of the fluentd server (lowest priority)

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
2. Or `service_description` option, if present
  * If the value exceeds the maximum 128 bytes, it causes a config error.
3. Or the tag name (lowest priority)
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
2. Or `return_code` option, if present
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
  return_code_field retcode
</match>
```

When the record
`{"num" => 42, "retcode" => "WARNING"}` is input to the tag `ddos`,
the plugin sends a service check with the return code `1`,
which means WARNING.

When the record
`{"num" => 42}` is input to the tag `ddos`,
the plugin sends a service check with the default return code `3`.

#### Plugin output

The plugin output is determined as below.

1. The field specified by `plugin_output_field` option,
   if present (highest priority)
  * If the value exceeds the maximum 512 bytes, it will be truncated.
2. `plugin_output` option
  * If the value exceeds the maximum 512 bytes, it causes a config error.
3. JSON notation of the record (lowest priority)
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
