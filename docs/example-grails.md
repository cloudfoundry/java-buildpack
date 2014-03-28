# Grails Examples
The Java Buildpack treats Grails applications as normal Servlet applications built as WAR files.  The following example shows how to deploy the sample application located in the [Java Test Applications][j].

**Note:** The Grails community recommends running applications with no less than 768M of memory.

```bash
$ ./grailsw war
$ cf push grails-application -m 768M -p target/grails-application-0.1.war -b https://github.com/cloudfoundry/java-buildpack.git
-----> Downloading Open Jdk JRE 1.7.0_51 from http://.../openjdk/lucid/x86_64/openjdk-1.7.0_51.tar.gz (0.0s)
       Expanding Open Jdk JRE to .java-buildpack/open_jdk_jre (1.1s)
-----> Downloading Spring Auto Reconfiguration 0.8.7 from http://.../auto-reconfiguration/auto-reconfiguration-0.8.7.jar (0.0s)
       Modifying /WEB-INF/web.xml for Auto Reconfiguration
-----> Downloading Tomcat 7.0.50 from http://.../tomcat/tomcat-7.0.50.tar.gz (0.0s)
       Expanding Tomcat to .java-buildpack/tomcat (0.1s)
-----> Downloading Buildpack Tomcat Support 1.1.1 from http://.../tomcat-buildpack-support/tomcat-buildpack-support-1.1.1.jar (0.0s)
-----> Uploading droplet (68M)

$ curl ...cfapps.io
ok
```

[j]: https://github.com/cloudfoundry/java-test-applications/tree/master/grails-application
