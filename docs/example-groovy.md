# Groovy Examples
The Java Buildpack can run Groovy applications written with the [Ratpack framework][r] and from raw `.groovy` files (no pre-compilation).

## Raw Groovy
The following example shows how deploy the sample application located in the [Java Test Applications][j].

```bash
$ cf push groovy-application -b https://github.com/cloudfoundry/java-buildpack.git
-----> Downloading Open Jdk JRE 1.7.0_51 from http://.../openjdk/lucid/x86_64/openjdk-1.7.0_51.tar.gz (0.0s)
       Expanding Open Jdk JRE to .java-buildpack/open_jdk_jre (1.3s)
-----> Downloading Spring Auto Reconfiguration 0.8.7 from http://.../auto-reconfiguration/auto-reconfiguration-0.8.7.jar (0.0s)
-----> Downloading Groovy 2.2.1 from http://.../groovy/groovy-2.2.1.zip (0.0s)
       Expanding Groovy to .java-buildpack/groovy (0.4s)
-----> Uploading droplet (82M)

$ curl ...cfapps.io
ok
```

[j]: https://github.com/cloudfoundry/java-test-applications/tree/master/groovy-application
[r]: http://www.ratpack.io
