# Logging

The Java buildpack logs to both
`<app dir>/.buildpack-diagnostics/buildpack.log` and standard error.
Logs are filtered according to the configured log level.

If the buildpack fails with an exception, the exception message is logged with a
log level of `ERROR` whereas the exception stack trace is logged with a log
level of `DEBUG` to prevent users from seeing stack traces by default.

## Sensitive Information in Logs

The Java buildpack logs sensitive information, such as environment variables which may contain security
credentials.

_You should be careful not to expose this information
inadvertently_, for example by posting standard error stream contents or the contents of
`<app dir>/.buildpack-diagnostics/buildpack.log` to a public discussion list.  

## Logger Usage
The `LoggerFactory` class in the `JavaBuildpack::Diagnostics` module
manages a single instance of a subclass of the standard Ruby `Logger`.
In normal usage, the `Buildpack` class creates a logger which is shared
by all other classes and which is retrieved from the `LoggerFactory` as necessary:

    logger = LoggerFactory.get_logger

This logger is used like the standard Ruby logger and supports
both parameter and block forms:

    logger.info('success')
    logger.debug { "#{costly_method}" }

## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][].

The log level is configured by setting an environment variable
`$JBP_LOG_LEVEL` to one of:

    DEBUG | INFO | WARN | ERROR | FATAL

For example:

    cf set-env <app name> JBP_LOG_LEVEL DEBUG

If `JBP_LOG_LEVEL` is not set, the default log level is read from the configuration in
[`config/logging.yml`][].

The logging levels in `JBP_LOG_LEVEL` and `config/logging.yml` may be
specified using any mixture of upper and lower case.

Ruby's verbose and debug modes override the default log level to `DEBUG` unless
`JBP_LOG_LEVEL` has been set, in which case this takes priority.

[Configuration and Extension]: ../README.md#Configuration-and-Extension
[`config/logging.yml`]: ../config/logging.yml