# Logging

The Java buildpack logs all messages, regardless of severity to `<app dir>/.java-buildpack.log`.  It also logs messages to `$stderr`, filtered by a configured severity.

If the buildpack fails with an exception, the exception message is logged with a log level of `ERROR` whereas the exception stack trace is logged with a log level of `DEBUG` to prevent users from seeing stack traces by default.

## Sensitive Information in Logs
The Java buildpack logs sensitive information, such as environment variables which may contain security credentials.

_You should be careful not to expose this information inadvertently_, for example by posting standard error stream contents or the contents of `<app dir>/.java-buildpack.log` to a public discussion list.

## Logger Usage
The `JavaBuildpack::Logging::LoggerFactory` class manages instances that meet the contract of the standard Ruby `Logger`. In normal usage, the `Buildpack` class configures the `LoggerFactory`.  `Logger` instances are then retrieved for classes that require them:

```ruby
@logger = JavaBuildpack::Logging::LoggerFactory.get_logger DownloadCache
```

This logger is used like the standard Ruby logger and supports both parameter and block forms:

```
logger.info('success')
logger.debug { "#{costly_method}" }
```

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The console logging severity filter is set to `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL` using the following strategies in descending priority:

1. `$JBP_LOG_LEVEL` environment variable.  This can be set using the `cf set-env <app name> JBP_LOG_LEVEL DEBUG` command.
2. Ruby `--verbose` and `--debug` flags.  Setting either of these is the equivalent of setting the log severity level to `DEBUG`.
3. `default_log_level` value in [`config/logging.yml`][].
4. Fallback to `INFO` if none of the above are set.

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/logging.yml`]: ../config/logging.yml
