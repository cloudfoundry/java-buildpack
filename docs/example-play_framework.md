# Play Framework Examples
The Java Buildpack can run [Play Framework][p] applications packaged either with the `play dist` or `play stage` commands.

## `play dist`
The following example shows how deploy the sample application located in the [Java Test Applications][j].

```bash
$ play dist
$ cf push play-application -p target/universal/play-application-1.0-SNAPSHOT.zip -b https://github.com/cloudfoundry/java-buildpack.git

-----> Downloading Open Jdk JRE 1.7.0_51 from http://.../openjdk/lucid/x86_64/openjdk-1.7.0_51.tar.gz (0.0s)
       Expanding Open Jdk JRE to .java-buildpack/open_jdk_jre (1.2s)
-----> Downloading Play Framework Auto Reconfiguration 0.8.7 from http://.../auto-reconfiguration/auto-reconfiguration-0.8.7.jar (0.0s)
-----> Downloading Spring Auto Reconfiguration 0.8.7 from http://.../auto-reconfiguration/auto-reconfiguration-0.8.7.jar (0.0s)
-----> Uploading droplet (71M)

$ curl ...cfapps.io
ok
```

## `play stage`
The following example shows how deploy the sample application located in the [Java Test Applications][j].

```bash
$ play stage
$ cf push play-application -p target/universal/stage -b https://github.com/cloudfoundry/java-buildpack.git

-----> Downloading Open Jdk JRE 1.7.0_51 from http://.../openjdk/lucid/x86_64/openjdk-1.7.0_51.tar.gz (0.0s)
       Expanding Open Jdk JRE to .java-buildpack/open_jdk_jre (1.2s)
-----> Downloading Play Framework Auto Reconfiguration 0.8.7 from http://.../auto-reconfiguration/auto-reconfiguration-0.8.7.jar (0.0s)
-----> Downloading Spring Auto Reconfiguration 0.8.7 from http://.../auto-reconfiguration/auto-reconfiguration-0.8.7.jar (0.0s)
-----> Uploading droplet (71M)

$ curl ...cfapps.io
ok
```

[j]: https://github.com/cloudfoundry/java-test-applications/tree/master/play-application
[p]: http://www.playframework.com
