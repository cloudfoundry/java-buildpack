# Security

In addition to security considerations associated with JREs, containers, and frameworks, the
following points pertain to the security of the buildpack itself.

## Buildpack Forks

If you fork the Java buildpack, it is important to keep the fork up to date with the
original repository. This will ensure that your fork runs with any security fixes that may be necessary.

## Security and Logs

See [Sensitive Information in Logs](logging.md#Sensitive-Information-in-Logs).