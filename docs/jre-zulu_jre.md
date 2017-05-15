# Azul Zulu JRE
Azul Zulu JRE provides Java runtimes developed by Azul team.  Versions of Java from the `1.6`, `1.7`, and `1.8` levels are available.  Unless otherwise configured, the version of Java that will be used is specified in [`config/zulu_jre.yml`][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Unconditional</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>open-jdk-like-jre=&lang;version&rang;, open-jdk-like-memory-calculator=&lang;version&rang;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script.


## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The JRE can be configured by modifying the [`config/zulu_jre.yml`][] file in the buildpack fork.  The JRE uses the [`Repository` utility support][repositories] and so, it supports the [version syntax][]  defined there.

To use Zulu JRE instead of OpenJDK without forking java-buildpack, set environment variable:

`cf set-env <app_name> JBP_CONFIG_COMPONENTS '{jres: ["JavaBuildpack::Jre::ZuluJRE"]}'`

`cf restage <app_name>`

| Name | Description
| ---- | -----------
| `memory_calculator` | Memory calculator defaults, described below under "Memory".
| `repository_root` | The URL of the Zulu repository index ([details][repositories]).
| `version` | The version of Java runtime to use. Note: version 1.8.0 and higher require the `memory_sizes` and `memory_heuristics` mappings to specify `metaspace` rather than `permgen`.

### Additional Resources
The JRE can also be configured by overlaying a set of resources on the default distribution. To do this, add files to the `resources/zulu_jre` directory in the buildpack fork.

#### JCE Unlimited Strength
To add the JCE Unlimited Strength `local_policy.jar`, add your file to `resources/zulu_jre/lib/security/local_policy.jar`.  This file will be overlayed onto the Zulu distribution.

#### Custom CA Certificates
To add custom SSL certificates, add your `cacerts` file to `resources/zulu_jre/lib/security/cacerts`.  This file will be overlayed onto the Zulu distribution.

### Memory
The total available memory for the application's container is specified when an application is pushed.
The Java buildpack uses this value to control the JRE's use of various
regions of memory and logs the JRE memory settings when the application starts or restarts.
These settings can be influenced by configuring
the `stack_threads` and/or `class_count` mappings (both part of the `memory_calculator` mapping),
and/or Java options relating to memory.

Note: If the total available memory is scaled up or down, the Java buildpack will re-calculate the JRE memory settings the next time the application is started.

#### Total Memory

The user can change the container's total memory available to influence the JRE memory settings.
Unless the user specifies the heap size Java option (`-Xmx`), increasing or decreasing the total memory
available results in the heap size setting increasing or decreasing by a corresponding amount.

#### Stack Threads

The amount of memory that should be allocated to stacks is given as an amount of memory per
thread with the Java option `-Xss`. If an explicit number of
threads should be used for the calculation of stack memory, then it should be specified as in
the following example:

```yaml
stack_threads: 500
```

#### Loaded Classes

The amount of memory that is allocated to metaspace and compressed class space (or, on Java 7, the permanent generation) is calculated from an estimate of the number of classes that will be loaded. The default behaviour is to estimate the number of loaded classes as a fraction of the number of class files in the application.
If a specific number of loaded classes should be used for calculations, then it should be specified as in the following example:

```yaml
class_count: 500
```

#### Java Options

If the JRE memory settings need to be fine-tuned, the user can set one or more Java memory options to
specific values. The heap size can be set explicitly, but changing the value of options other
than the heap size can also affect the heap size. For example, if the user increases
the maximum direct memory size from its default value of 10 Mb to 20 Mb, then this will
reduce the calculated heap size by 10 Mb.

#### Memory Calculation
Memory calculation happens before every `start` of an application and is performed by an external program, the [Java Buildpack Memory Calculator]. There is no need to `restage` an application after scaling the memory as restarting will cause the memory settings to be recalculated.

The container's total available memory is allocated into heap, metaspace and compressed class space (or permanent generation for Java 7),
direct memory, and stack memory settings.

The memory calculation is described in more detail in the [Memory Calculator's README].
  
The inputs to the memory calculation, except the container's total memory (which is unknown at staging time), are logged during staging, for example:
```
Loaded Classes: 13974, Threads: 300, JAVA_OPTS: ''
```

The container's total memory is logged during `cf push` and `cf scale`, for example:
```
     state     since                    cpu    memory       disk         details
#0   running   2017-04-10 02:20:03 PM   0.0%   896K of 1G   1.3M of 1G
```

The JRE memory settings are logged when the application is started or re-started, for example:
```
JVM Memory Configuration: -XX:MaxDirectMemorySize=10M -XX:MaxMetaspaceSize=99199K \
    -XX:ReservedCodeCacheSize=240M -XX:CompressedClassSpaceSize=18134K -Xss1M -Xmx368042K
```

[`config/components.yml`]: ../config/components.yml
[`config/zulu_jre.yml`]: ../config/zulu_jre.yml
[Configuration and Extension]: ../README.md#configuration-and-extension
[Java Buildpack Memory Calculator]: https://github.com/cloudfoundry/java-buildpack-memory-calculator
[Memory Calculator's README]: https://github.com/cloudfoundry/java-buildpack-memory-calculator
[Zulu JRE]: jre-zulu_jre.md
[Azul Zulu]: https://www.azul.com/products/zulu/
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
