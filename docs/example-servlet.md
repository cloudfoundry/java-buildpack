# Servlet Examples
The Java Buildpack can run Servlet-based applications provided that they are packaged as a WAR file.

## Gradle
The following example shows how deploy the sample application located in the [Java Test Applications][j].

```bash
$ gradle build
$ cf push web-servlet-2-application -p build/libs/web-servlet-2-application-1.0.0.BUILD-SNAPSHOT.war -b https://github.com/cloudfoundry/java-buildpack.git

-----> Downloading Open Jdk JRE 1.7.0_51 from http://.../openjdk/lucid/x86_64/openjdk-1.7.0_51.tar.gz (0.0s)
       Expanding Open Jdk JRE to .java-buildpack/open_jdk_jre (1.1s)
-----> Downloading Spring Auto Reconfiguration 0.8.7 from http://.../auto-reconfiguration/auto-reconfiguration-0.8.7.jar (0.0s)
       Modifying /WEB-INF/web.xml for Auto Reconfiguration
-----> Downloading Tomcat 7.0.50 from http://.../tomcat/tomcat-7.0.50.tar.gz (0.0s)
       Expanding Tomcat to .java-buildpack/tomcat (0.1s)
-----> Downloading Buildpack Tomcat Support 1.1.1 from http://.../tomcat-buildpack-support/tomcat-buildpack-support-1.1.1.jar (0.0s)
-----> Uploading droplet (51M)

$ curl ...cfapps.io
ok
```

## Maven
The following example shows how deploy the sample application located in the [Java Test Applications][j].

```bash
$ mvn package
$ cf push web-servlet-2-application -p target/web-servlet-2-application-1.0.0.BUILD-SNAPSHOT.war -b https://github.com/cloudfoundry/java-buildpack.git

-----> Downloading Open Jdk JRE 1.7.0_51 from http://.../openjdk/lucid/x86_64/openjdk-1.7.0_51.tar.gz (0.0s)
       Expanding Open Jdk JRE to .java-buildpack/open_jdk_jre (1.1s)
-----> Downloading Spring Auto Reconfiguration 0.8.7 from http://.../auto-reconfiguration/auto-reconfiguration-0.8.7.jar (0.0s)
       Modifying /WEB-INF/web.xml for Auto Reconfiguration
-----> Downloading Tomcat 7.0.50 from http://.../tomcat/tomcat-7.0.50.tar.gz (0.0s)
       Expanding Tomcat to .java-buildpack/tomcat (0.1s)
-----> Downloading Buildpack Tomcat Support 1.1.1 from http://.../tomcat-buildpack-support/tomcat-buildpack-support-1.1.1.jar (0.0s)
-----> Uploading droplet (51M)

$ curl ...cfapps.io
ok
```

[j]: https://github.com/cloudfoundry/java-test-applications/tree/master/web-servlet-2-application
