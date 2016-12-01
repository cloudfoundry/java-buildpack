# Spring Boot CLI Examples
The Java Buildpack can run [Spring Boot CLI][s] applications packaged with the `spring grab` or `spring jar` commands.

## `spring grab`
The following example shows how deploy the sample application located in the [Java Test Applications][j].

```bash
$ spring grab *.groovy
$ $ cf push spring-boot-cli-application -b https://github.com/cloudfoundry/java-buildpack.git

-----> Downloading Open Jdk JRE 1.7.0_51 from http://.../openjdk/lucid/x86_64/openjdk-1.7.0_51.tar.gz (0.0s)
       Expanding Open Jdk JRE to .java-buildpack/open_jdk_jre (1.2s)
-----> Downloading Spring Auto Reconfiguration 0.8.7 from http://.../auto-reconfiguration/auto-reconfiguration-0.8.7.jar (0.0s)
-----> Downloading Spring Boot CLI 1.0.0_RC2 from http://.../spring-boot-cli/spring-boot-cli-1.0.0_RC2.tar.gz (0.0s)
       Expanding Spring Boot CLI to .java-buildpack/spring_boot_cli (0.1s)
-----> Uploading droplet (59M)

$ curl ...cfapps.io
ok
```

## `spring jar`
The following example shows how deploy the sample application located in the [Java Test Applications][j].

```bash
$ spring jar spring-boot-cli-application-1.0.0.BUILD-SNAPSHOT.jar *.groovy
$ cf push spring-boot-cli-application -p spring-boot-cli-application-1.0.0.BUILD-SNAPSHOT.jar -b https://github.com/cloudfoundry/java-buildpack.git

-----> Downloading Open Jdk JRE 1.7.0_51 from http://.../openjdk/lucid/x86_64/openjdk-1.7.0_51.tar.gz (0.0s)
       Expanding Open Jdk JRE to .java-buildpack/open_jdk_jre (1.2s)
-----> Downloading Spring Auto Reconfiguration 0.8.7 from http://.../auto-reconfiguration/auto-reconfiguration-0.8.7.jar (0.0s)
-----> Uploading droplet (52M)

$ curl ...cfapps.io
ok
```

[j]: https://github.com/cloudfoundry/java-test-applications/tree/master/spring-boot-cli-application
[s]: http://projects.spring.io/spring-boot/
