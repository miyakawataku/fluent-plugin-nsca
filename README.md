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
* `port` (default i 5667)
  * The port on which the NSCA daemon is running.
* `password` (default is empty string)
  * The password for authentication and encryption.

### Payload

A service check for the NSCA server
comprises the following four fields.

* Host name
  * The name of the monitored host.
  * The corresponding property in the Nagios configuration is
    `host_name` property in a `host` definition.
* Service description
  * The name of the monitored service.
  * The corresponding property in the Nagios configuration is
    `service_description` property in a `service` definition.
* Return code
  * The severity of the service status.
  * 0 (OK), 1 (WARNING), 2 (CRITICAL) or 3 (UNKNOWN).
* Plugin output
  * A description of the service status.

The destination of checks
are identified by the pair of the host name and the service description.

#### Host name

The host name is determined as below.

1. The host name of the fluentd server (lowest priority)
2. `host_name` option
3. The field specified by `host_name_field` option (highest priority)

For example,
let the fluentd server have the host name "fluent",
and the configuration file contain the section below:

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

Be aware that if the host name exceeds 64 bytes, it will be truncated.

#### Service description

The service description is determined as below.

1. The tag name (lowest priority)
2. `service_description` option
3. The field specified by `service_description_field` option (highest priority)

For example,
let the configuration file contain the section below:

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

Be aware that if the service description exceeds 128 bytes,
it will be truncated.

#### Return code

The return code is determined as below.

1. 3 or UNKNOWN (lowest priority)
2. `return_code` option
  * The permitted values are `0`, `1`, `2`, `3`,
    and `OK`, `WARNING`, `CRITICAL`, `UNKNOWN`.
3. The field specified by `return_code_field` option (highest priority)
  * The values permitted for the field are integers `0`, `1`, `2`, `3`
    and strings `"0"`, `"1"`, `"2"`, `"3"`,
    `"OK"`, `"WARNING"`, `"CRITICAL"`, `"UNKNOWN"`.
  * If the field contains a value not permitted,
    the plugin falls back to `return_code` if present, or to 3 (UNKNOWN).

For example,
let the configuration file contain the section below:

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

1. JSON notation of the record (lowest priority)
2. `plugin_output` option
3. The field specified by `plugin_output_field` option (highest priority)

For example,
let the configuration file contain the section below:

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

Be aware that if the plugin output exceeds 512 bytes,
it will be truncated.

## Installation (doesn't work yet!)

If you are using td-agent, execute the command below.

    $ sudo /usr/lib64/fluent/ruby/bin/fluent-gem fluent-plugin-nsca

Then add `match` section to your configuration file.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
