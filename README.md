# Cloud Foundry Java Buildpack
[![Build Status](https://travis-ci.org/cloudfoundry/java-buildpack.png?branch=master)](https://travis-ci.org/cloudfoundry/java-buildpack)
[![Dependency Status](https://gemnasium.com/cloudfoundry/java-buildpack.png)](http://gemnasium.com/cloudfoundry/java-buildpack)
[![Code Climate](https://codeclimate.com/github/cloudfoundry/java-buildpack.png)](https://codeclimate.com/github/cloudfoundry/java-buildpack)

`java-buildpack` is a [Cloud Foundry][cf] buildpack for running Java applications

[cf]: http://www.cloudfoundry.com

# Buildpack Users
The buildpack allows you to configure the both the vendor and version of the Java runtime your application should use.  To configure these, you can put a `system.properties` file into your pushed artifact.

## `system.properties`
If a `system.properties` file exists anywhere within your artifact's filesystem and the following properties have been set, they will be read and used to select the Java runtime for your application:

| Name | Description
| ---- | -----------
| `java.runtime.vendor` | The vendor of the Java runtime to use.  The legal values are defined by the keys in [`config/jres.yml`][jres_yml].
| `java.runtime.version` | The version of the Java runtime to use.  The legal values are defined by the keys in [`index.yml`][index_yml]
| `java.runtime.stack.size` | The Java stack size to use. For example, a value of 256k will result in the java command line option -Xss=256k. Values containing whitespace are rejected with an error, but all others values appear without modification on the java command line appended to -Xss=. 
| `java.runtime.heap.size.maximum` | The Java maximum heap size to use. For example, a value of 64m will result in the java command line option -Xmx=64m. Values containing whitespace are rejected with an error, but all others values appear without modification on the java command line appended to -Xmx=. 

An example `system.properties` file would to contain the following:
```java
java.runtime.vendor=openjdk
java.runtime.version=1.7.0_21
```
## JRE Version Syntax and Ordering
JREs versions are composed of major, minor, micro, and optional qualifier parts (`<major>.<minor>.<micro>[_<qualifier>]`).  The major, minor, and micro parts must be numeric.  The qualifier part is composed of letters, digits, and hyphens.  The lexical ordering of the qualifier is:

1. hyphen
2. lowercase letters
3. uppercase letters
4. digits

## JRE Version Wildcards
In addition to declaring a specific version of JRE to use, you can also specify a bounded range of JRES to use.  Appending the `+` symbol to a version prefix chooses the latest JRE that begins with the prefix.

| Example | Description
| ------- | -----------
| `1.+`   	| Selects the greatest available version less than `2.0.0`.
| `1.7.+` 	| Selects the greatest available version less than `1.8.0`.
| `1.7.0_+` | Selects the greatest available version less than `1.7.1`. Use this syntax to stay up to date with the latest security releases in a particular version.

## Default JRE
If the user does not specify a JRE vendor and version, a JRE is selected automatically.  The selection algorithm is as follows:

1. If a single vendor is available, it is selected.  If zero or more than one vendor is available, the buildpack will fail.
2. The latest version of JRE for the selected vendor is chosen.

[jres_yml]: config/jres.yml
[index_yml]: http://jres.gopivotal.com.s3.amazonaws.com/lucid/x86_64/openjdk/index.yml


# Buildpack Developers
This buildpacks is designed to be extensible by other developers.  To this end, various bits of configuration are exposed that make it simple to add functionality.

## Adding JRES
By default, this buildpack only allows users to choose from [OpenJDK][openjdk] JREs.  To allow users to choose a JRE from other vendors, these vendors must be specified in [`config/jres.yml`][jres_yml].  The file is [YAML][yaml] formatted  and in the simplest case is a mapping from a vendor name to a `String` repository root.

```yaml
<vendor name>: <JRE repository root URI>
```

When configured like this, if the user does not specify a version of the JRE to use, the latest possible version will be selected.  If a particular JRE should use a default that is not the latest (e.g. using `1.7.0_21` instead of `1.8.0_M7`), the default version can be specified by using a `Hash` instead of a `String` as the value.

```yaml
<vendor name>:
  default_version: <default version pattern>
  repository_root: <JRE repository root URI>
```

The JRE repository root must contain a `/index.yml` file ([example][index_yml]).  This file is also [YAML][yaml] formatted with the following syntax:

```yaml
<JRE version>: <path relative to JRE repository root>
```

The JRES uploaded to the repository must be gzipped TAR files and have no top-level directory ([example][example_jre]).

An example filesystem might look like:

```plain
/index.yml
/openjdk-1.6.0_27.tar.gz
/openjdk-1.7.0_21.tar.gz
/openjdk-1.8.0_M7.tar.gz
```

[openjdk]: http://openjdk.java.net
[yaml]: http://www.yaml.org
[example_jre]: http://jres.gopivotal.com.s3.amazonaws.com/lucid/x86_64/openjdk/openjdk-1.8.0_M7.tar.gz
