# Debugging the Buildpack
The buildpack is designed to be easy to configure, but it is still possible that something will go wrong. A configuration property might have an invalid value, or a framework may not be detected the way you expect. When these problems happen, the buildpack can tell you quite a bit about what went wrong.

## Debug Logging
By default the buildpack only logs the main staging steps, such as the detected container, the selected JRE, and the installed frameworks. All buildpack output is written to the staging output: you see it during `cf push`, and you can retrieve it later with `cf logs <APP> --recent`. The buildpack does not write a log file into the application.

To include debug messages in the staging output, set the `BP_DEBUG` environment variable and restage the application:

```bash
cf set-env <APP> BP_DEBUG true
cf restage <APP>
```

Only the presence of `BP_DEBUG` counts: any non-empty value enables debug logging during staging, including `false`, `0`, `OFF`, or `NONE`. To disable debug logging, unset the variable.

The debug messages show, for example, which container detection checks were tried, how the loaded class count was calculated, and why frameworks were or were not installed:

```text
-----> Java Buildpack version 5.1.0
-----> Supplying Java
       DEBUG: Play: Checking buildDir: /home/vcap/app
       DEBUG: Play: Trying Pre22Staged detection
       ...
       DEBUG: Play: No Play Framework detected
       DEBUG: Detected Dist ZIP application with start script: bin/application
       Detected container: Dist ZIP
       ...
       DEBUG: Counted 14776 classes (35% of 42219 total)
       ...
       DEBUG: New Relic not detected
       DEBUG: Datadog Javaagent: DD_API_KEY not set and no service binding found
       DEBUG: Elastic APM Agent: No elastic-apm service found
       DEBUG: MariaDB JDBC: No MariaDB/MySQL service detected
       ...
```

Remove the variable again when you are done, and restage:

```bash
cf unset-env <APP> BP_DEBUG
cf restage <APP>
```

If you set `BP_DEBUG` in the `env` block of your `manifest.yml`, removing it from the manifest is not enough: `cf push` and `cf restage` keep environment variables that were set before. Use `cf unset-env` to remove it.

## Running the Buildpack Locally
Sometimes logging is not enough, and inspecting the staged files is the fastest way to diagnose a problem. You can run the buildpack locally, without Cloud Foundry, in a container that uses the same stack image as Cloud Foundry.

### Requirements

* Docker
* A packaged buildpack, for example `java-buildpack-cflinuxfs4-vX.Y.Z.zip` from the [releases](https://github.com/cloudfoundry/java-buildpack/releases) page, or one built from source with `./scripts/package.sh` (see [DEVELOPING.md](DEVELOPING.md))
* Your application, exploded into a directory (for example, unzip a JAR, WAR, or distZip)

### Example invocation

Unzip the buildpack and the application into a working directory:

```bash
mkdir -p /tmp/jbp/bp /tmp/jbp/app
unzip -q java-buildpack-cflinuxfs4-vX.Y.Z.zip -d /tmp/jbp/bp
unzip -q my-application.jar -d /tmp/jbp/app
```

Run the `supply`, `finalize`, and `release` phases in the `cflinuxfs4` stack image. `CF_STACK` is required. Add `VCAP_SERVICES` if your application needs service bindings during staging:

```bash
docker run --rm -it \
  -e CF_STACK=cflinuxfs4 \
  -e BP_DEBUG=true \
  -v /tmp/jbp:/s \
  cloudfoundry/cflinuxfs4 bash -c '
    mkdir -p /home/vcap/app /tmp/cache /home/vcap/deps/0 /tmp/profile.d
    cp -r /s/app/. /home/vcap/app/
    /s/bp/bin/supply   /home/vcap/app /tmp/cache /home/vcap/deps 0
    /s/bp/bin/finalize /home/vcap/app /tmp/cache /home/vcap/deps 0 /tmp/profile.d
    /s/bp/bin/release  /home/vcap/app
    bash'
```

The final `bash` leaves you in a shell in the container, where you can inspect the staged application in `/home/vcap/app` and the installed dependencies (JRE, frameworks) in `/home/vcap/deps/0`. The `release` phase prints the `web` start command.

To test the buildpack itself, see the unit and integration tests described in [DEVELOPING.md](DEVELOPING.md).
