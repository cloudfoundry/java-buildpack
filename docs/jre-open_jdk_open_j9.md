# OpenJDK JRE with Eclipse OpenJ9
The OpenJDK JRE with [Eclipse OpenJ9][] provides a Java runtimes from the [OpenJDK][] project that utilizes the Eclipse OpenJ9 JVM.  Versions of Java from the `1.8` and `1.11` lines are available.  Unless otherwise configured, the version of Java that will be used is specified in [`config/open_jdk_open_j9.yml`][].  For more information about [Eclipse OpenJ9][], see the Eclipse Foundation page.

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
    <td><tt>open-jdk-open-j9-initializer=&lang;version&rang;, jvmkill=&lang;version&rang;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The JRE can be configured by modifying the [`config/open_jdk_open_j9.yml`][] file in the buildpack fork.  The JRE uses the [`Repository` utility support][repositories] and so it supports the [version syntax][]  defined there.

To use OpenJDK JRE with [Eclipse OpenJ9][] instead of OpenJDK without forking java-buildpack, set environment variable:

`cf set-env <app_name> JBP_CONFIG_COMPONENTS '{jres: ["JavaBuildpack::Jre::OpenJdkOpenJ9"]}'`

`cf restage <app_name>`

| Name | Description
| ---- | -----------
| `jre.repository_root` | The URL of the OpenJDK repository index ([details][repositories]).
| `jre.version` | The version of Java runtime to use. Candidate versions can be found on [AdoptOpenJDK][].
| `jvmkill.repository_root` | The URL of the `jvmkill` repository index ([details][repositories]).
| `jvmkill.version` | The version of `jvmkill` to use.  Candidate versions can be found in the listings for [mountainlion][jvmkill-mountainlion] and [trusty][jvmkill-trusty].

### Additional Resources
The JRE can also be configured by overlaying a set of resources on the default distribution. To do this, add files to the `resources/open_jdk_open_j9` directory in the buildpack fork.

#### Custom CA Certificates
To add custom SSL certificates, add your `cacerts` file to `resources/open_jdk_open_j9/jre/lib/security/cacerts`.  This file will be overlayed onto the OpenJDK distribution.

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
The total available memory for the application's container is specified when an application is pushed. For this JRE, The Java buildpack does *not* use this value to control the JRE's use of various regions of memory. This is left up to [OpenJ9 defaults][], which may or may not work for your app.

The user can change the container's total memory available and the user can specify [custom memory settings][] like the heap size (`-Xmx`) using Java option. Increasing or decreasing the total memory available to the container makes more memory available for heap & non-heap usage. The total memory limit for the app needs to be large enough to encompass all segments of the memory used by the JVM, not just heap space.


[`config/open_jdk_open_j9.yml`]: ../config/open_jdk_open_j9.yml
[Configuration and Extension]: ../README.md#configuration-and-extension
[Java Buildpack Memory Calculator]: https://github.com/cloudfoundry/java-buildpack-memory-calculator
[jvmkill-mountainlion]: http://download.pivotal.io.s3.amazonaws.com/jvmkill/mountainlion/x86_64/index.yml
[jvmkill-trusty]: http://download.pivotal.io.s3.amazonaws.com/jvmkill/trusty/x86_64/index.yml
[Memory Calculator's README]: https://github.com/cloudfoundry/java-buildpack-memory-calculator
[OpenJDK]: http://openjdk.java.net
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
[Volume Service]: https://docs.cloudfoundry.org/devguide/services/using-vol-services.html
[Eclipse OpenJ9]: https://www.eclipse.org/openj9/
[OpenJ9 defaults]: https://www.eclipse.org/openj9/docs/openj9_defaults/
[custom memory settings]: https://www.eclipse.org/openj9/docs/x_jvm_commands/
[AdoptOpenJDK]: https://adoptopenjdk.net/
