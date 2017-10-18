# OpenJDK JRE
The OpenJDK JRE provides Java runtimes from the [OpenJDK][] project.  Versions of Java from the `1.6`, `1.7`, and `1.8` lines are available.  Unless otherwise configured, the version of Java that will be used is specified in [`config/open_jdk_jre.yml`][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Unconditional.  Existence of a single bound Volume Service will result in Terminal heap dumps being written.
      <ul>
        <li>Existence of a Volume Service service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>heap-dump</code> as a substring.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>open-jdk=&lang;version&rang;, open-jdk-like-memory-calculator=&lang;version&rang;, jvmkill=&lang;version&rang;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The JRE can be configured by modifying the [`config/open_jdk_jre.yml`][] file in the buildpack fork.  The JRE uses the [`Repository` utility support][repositories] and so it supports the [version syntax][]  defined there.

| Name | Description
| ---- | -----------
| `jre.repository_root` | The URL of the OpenJDK repository index ([details][repositories]).
| `jre.version` | The version of Java runtime to use.  Candidate versions can be found in the listings for [mountainlion][] and [trusty][]. Note: version 1.8.0 and higher require the `memory_sizes` and `memory_heuristics` mappings to specify `metaspace` rather than `permgen`.
| `jvmkill.repository_root` | The URL of the `jvmkill` repository index ([details][repositories]).
| `jvmkill.version` | The version of `jvmkill` to use.  Candidate versions can be found in the listings for [mountainlion][jvmkill-mountainlion] and [trusty][jvmkill-trusty].
| `memory_calculator` | Memory calculator defaults, described below under "Memory".

### Additional Resources
The JRE can also be configured by overlaying a set of resources on the default distribution. To do this, add files to the `resources/open_jdk_jre` directory in the buildpack fork.

#### JCE Unlimited Strength
To add the JCE Unlimited Strength `local_policy.jar`, add your file to `resources/open_jdk_jre/lib/security/local_policy.jar`.  This file will be overlayed onto the OpenJDK distribution.

#### Custom CA Certificates
To add custom SSL certificates, add your `cacerts` file to `resources/open_jdk_jre/lib/security/cacerts`.  This file will be overlayed onto the OpenJDK distribution.

### `jvmkill`
The `jvmkill` agent runs when an application has experience a resource exhaustion event.  When this event occurs, the agent will print out a histogram of the first 100 largest types by total number of bytes.

```plain
Resource exhaustion event: the JVM was unable to allocate memory from the heap.
ResourceExhausted! (1/0)
| Instance Count | Total Bytes | Class Name                                    |
| 18273          | 313157136   | [B                                            |
| 47806          | 7648568     | [C                                            |
| 14635          | 1287880     | Ljava/lang/reflect/Method;                    |
| 46590          | 1118160     | Ljava/lang/String;                            |
| 8413           | 938504      | Ljava/lang/Class;                             |
| 28573          | 914336      | Ljava/util/concurrent/ConcurrentHashMap$Node; |
```

It will also print out a summary of all of the memory spaces in the JVM.

```plain
Memory usage:
   Heap memory: init 65011712, used 332392888, committed 351797248, max 351797248
   Non-heap memory: init 2555904, used 63098592, committed 64815104, max 377790464
Memory pool usage:
   Code Cache: init 2555904, used 14702208, committed 15007744, max 251658240
   PS Eden Space: init 16252928, used 84934656, committed 84934656, max 84934656
   PS Survivor Space: init 2621440, used 0, committed 19398656, max 19398656
   Compressed Class Space: init 0, used 5249512, committed 5505024, max 19214336
   Metaspace: init 0, used 43150616, committed 44302336, max 106917888
   PS Old Gen: init 43515904, used 247459792, committed 247463936, max 247463936
```

If a [Volume Service][] with the string `heap-dump` in its name or tag is bound to the application, terminal heap dumps will be written with the pattern `<CONTAINER_DIR>/<SPACE_NAME>-<SPACE_ID[0,8]>/<APPLICATION_NAME>-<APPLICATION_ID[0,8]>/<INSTANCE_INDEX>-<TIMESTAMP>-<INSTANCE_ID[0,8]>.hprof`

```plain
Heapdump written to /var/vcap/data/9ae0b817-1446-4915-9990-74c1bb26f147/pcfdev-space-e91c5c39/java-main-application-892f20ab/0-2017-06-13T18:31:29+0000-7b23124e.hprof
```

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

[`config/open_jdk_jre.yml`]: ../config/open_jdk_jre.yml
[Configuration and Extension]: ../README.md#configuration-and-extension
[Java Buildpack Memory Calculator]: https://github.com/cloudfoundry/java-buildpack-memory-calculator
[jvmkill-mountainlion]: http://download.pivotal.io.s3.amazonaws.com/jvmkill/mountainlion/x86_64/index.yml
[jvmkill-trusty]: http://download.pivotal.io.s3.amazonaws.com/jvmkill/trusty/x86_64/index.yml
[Memory Calculator's README]: https://github.com/cloudfoundry/java-buildpack-memory-calculator
[mountainlion]: http://download.pivotal.io.s3.amazonaws.com/openjdk/mountainlion/x86_64/index.yml
[OpenJDK]: http://openjdk.java.net
[repositories]: extending-repositories.md
[trusty]: http://download.pivotal.io.s3.amazonaws.com/openjdk/trusty/x86_64/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
[Volume Service]: https://docs.cloudfoundry.org/devguide/services/using-vol-services.html
