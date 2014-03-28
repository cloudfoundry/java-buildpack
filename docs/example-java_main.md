# Java Main Examples
The Java Buildpack can run Java applications with a `main()` method provided that they are packaged as [self-executable JARs][e].

## Gradle
The following example shows how deploy the sample application located in the [Java Test Applications][j].

```bash
$ gradle build
$ cf push java-main-application -p build/libs/java-main-application-1.0.0.BUILD-SNAPSHOT.jar -b https://github.com/cloudfoundry/java-buildpack.git

-----> Downloading Open Jdk JRE 1.7.0_51 from http://.../openjdk/lucid/x86_64/openjdk-1.7.0_51.tar.gz (0.0s)
       Expanding Open Jdk JRE to .java-buildpack/open_jdk_jre (1.2s)
-----> Downloading Spring Auto Reconfiguration 0.8.7 from http://.../auto-reconfiguration/auto-reconfiguration-0.8.7.jar (0.0s)
-----> Uploading droplet (48M)

$ curl ...cfapps.io
ok
```

## Maven
The following example shows how deploy the sample application located in the [Java Test Applications][j].

```bash
$ mvn package
$ cf push java-main-application -p target/java-main-application-1.0.0.BUILD-SNAPSHOT.jar -b https://github.com/cloudfoundry/java-buildpack.git

-----> Downloading Open Jdk JRE 1.7.0_51 from http://.../openjdk/lucid/x86_64/openjdk-1.7.0_51.tar.gz (0.0s)
       Expanding Open Jdk JRE to .java-buildpack/open_jdk_jre (1.2s)
-----> Downloading Spring Auto Reconfiguration 0.8.7 from http://.../auto-reconfiguration/auto-reconfiguration-0.8.7.jar (0.0s)
-----> Uploading droplet (48M)

$ curl ...cfapps.io
ok
```

[e]: https://github.com/cloudfoundry/java-buildpack/blob/master/docs/container-java_main.md
[j]: https://github.com/cloudfoundry/java-test-applications/tree/master/java-main-application
