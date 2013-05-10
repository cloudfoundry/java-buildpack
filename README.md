# Cloud Foundry Java Buildpack
[![Build Status](https://travis-ci.org/cloudfoundry/java-buildpack.png?branch=master)](https://travis-ci.org/cloudfoundry/java-buildpack)
[![Dependency Status](https://gemnasium.com/cloudfoundry/java-buildpack.png)](http://gemnasium.com/cloudfoundry/java-buildpack)
[![Code Climate](https://codeclimate.com/github/cloudfoundry/java-buildpack.png)](https://codeclimate.com/github/cloudfoundry/java-buildpack)

`java-buildpack` is a [Cloud Foundry][cf] buildpack for running Java applications

[cf]: http://www.cloudfoundry.com


# Configuration
The buildpack allows you to configure the both the vendor and version of the Java runtime your application should use.  To configure these, you can either put a `system.properties` file into your pushed artifact, or specify environment variables for your application.  By default the **OpenJDK 7** Java runtime is chosen.

## `system.properties`
If a `system.properties` file exists anywhere within your artifact's filesystem and the following properties have been set, they will be read and used to select the Java runtime for your application:

| Name |  Description
| ---- | -----------
| `java.runtime.vendor` | The vendor of the Java runtime to use.  Legal values are `oracle` or `openjdk`.
| `java.runtime.version` | The version of the Java runtime to use.  The legal values are dependent on the vendor, but are typically `6`, `7`, `8`, `1.6`, `1.7`, and `1.8` are acceptable.

An example `system.properties` file would to contain the following:
```java
java.runtime.vendor=openjdk
java.runtime.version=8
```

## Environment Variables
If the following environment variables have been set, they will be read and used to select the Java runtime for your application:

| Name |  Description
| ---- | -----------
| `JAVA_RUNTIME_VENDOR` | The vendor of the Java runtime to use.  Legal values are `oracle` or `openjdk`.
| `JAVA_RUNTIME_VERSION` | The version of the Java runtime to use.  The legal values are dependent on the vendor, but are typically `6`, `7`, `8`, `1.6`, `1.7`, and `1.8` are acceptable.

To set these properties for your application, do the following:
```plain
cf set-env my-app JAVA_RUNTIME_VENDOR openjdk
cf set-env my-app JAVA_RUNTIME_VERSION 8
```
