# fluent-plugin-nsca

[Fluentd](http://fluentd.org) output plugin to send service checks
to an [NSCA](http://exchange.nagios.org/directory/Addons/Passive-Checks/NSCA--2D-Nagios-Service-Check-Acceptor/details)
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

  ## The plugin output is not specified; hence the JSON notation of the record is used

</match>
```

### Connection

* `server` (default=localhost)
  * The IP address or the hostname of the host running the NSCA daemon.
* `port` (default=5667)
  * The port on which the NSCA daemon is running.
* `password` (default=(empty string))
  * The password for authentication and encryption.

### Payload

A service check to the NSCA server and the Nagios server
comprises the following four fields.

* Host name
  * Name of the monitored host.
  * The corresponding property in the Nagios configuration is `host_name` property in a `host` definition.
* Service description
  * Name of the monitored service.
  * The corresponding property in the Nagios configuration is `service_description` in a `service` definition.
* Return code
  * The severity of the service status.
  * 0 (OK), 1 (WARNING), 2 (CRITICAL) or 3 (UNKNOWN).
* Plugin output
  * An arbitrary text to describe the service status.

Checks are sent to the combination of (host name, service description)
with the return code and the plugin output.

#### Host name

The host name is determined as below.

1. The result of `hostname` command (lowest priority)
2. `host_name` option
  * The static host name string.
3. `host_name_field` option (highest priority)
  * The name of the field which contains the host name.

For example,
let the fluentd server have the host name "fluent",
and the configuration file contain the below line:

```apache
host_name_field monitee
```

When the record `{"num" => 42, "monitee" => "web.example.org"}`
is input with the setting above,
the plugin sends a service check with the host name "web.example.org".

When the record `{"num" => 42}` is input with the setting above,
the plugin sends a service check with the host name "fluent"
(the host name of the fluentd server).

#### Service description

The service description can be specified by one of the followin options.
If none of them is specified,
the plugin uses the tag as the service description.

* `service_description`
  * The static service description string.
* `service_description_field`
  * The name of the field which contains the service description.

#### Return code

The return code can be specified by one of the following options.
If none of them is specified,
the plugin uses 3 (UNKNOWN) as the return code.

* `return_code`
  * The static return code.
* `return_code_field`
  * The name of the field which contains the return code.

Numbers 0, 1, 2, 3, or strings '0', '1', '2', '3', 'OK', 'WARNING', 'CRITICAL' and 'UNKNOWN' are accepted.

#### Plugin output

The plugin output can be specified by one of the following options.
If none of them is specified,
the plugin uses the JSON notation of the record as the plugin output.

* `plugin_output`
  * The static plugin output.
* `plugin_output_field`
  * The name of the field which contains the plugin output.

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
