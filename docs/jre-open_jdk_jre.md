# OpenJDK JRE
The OpenJDK JRE provides Java runtimes from the [OpenJDK][] project.  Versions of Java from the `1.6`, `1.7`, and `1.8` lines are available.  Unless otherwise configured, the version of Java that will be used is specified in [`config/open_jdk_jre.yml`][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Unconditional</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>open-jdk=&lang;version&rang;, open-jdk-like-memory-calculator=&lang;version&rang;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The JRE can be configured by modifying the [`config/open_jdk_jre.yml`][] file in the buildpack fork.  The JRE uses the [`Repository` utility support][repositories] and so it supports the [version syntax][]  defined there.

| Name | Description
| ---- | -----------
| `memory_sizes` | Optional memory sizes, described below under "Memory Sizes".
| `memory_heuristics` | Default memory size weightings, described below under "Memory Weightings".
| `memory_initials` | Initial memory sizes, described below under "Memory Initials".
| `repository_root` | The URL of the OpenJDK repository index ([details][repositories]).
| `version` | The version of Java runtime to use.  Candidate versions can be found in the listings for [mountainlion][], [precise][], and [trusty][]. Note: version 1.8.0 and higher require the `memory_sizes` and `memory_heuristics` mappings to specify `metaspace` rather than `permgen`.

### Additional Resources
The JRE can also be configured by overlaying a set of resources on the default distribution. To do this, add files to the `resources/open_jdk_jre` directory in the buildpack fork.

#### JCE Unlimited Strength
To add the JCE Unlimited Strength `local_policy.jar`, add your file to `resources/open_jdk_jre/lib/security/local_policy.jar`.  This file will be overlayed onto the OpenJDK distribution.

#### Custom CA Certificates
To add custom SSL certificates, add your `cacerts` file to `resources/open_jdk_jre/lib/security/cacerts`.  This file will be overlayed onto the OpenJDK distribution.

### Memory
The total available memory is specified when an application is pushed as part of it's configuration. The Java buildpack uses this value to control the JRE's use of various regions of memory. The JRE memory settings can be influenced by configuring the `memory_sizes`, `memory_heuristics`, `memory_initials` and/or `stack_threads` mappings.

Note: If the total available memory is scaled up or down, the Java buildpack will re-calculate the JRE memory settings the next time the application is started.

Note: If setting an initial Stack size, depending on the version of Java and the operating system used by Cloud Foundry the JRE will require a minimum `-Xss` value. This tends to be between `100k` and `250k`.

#### Memory Sizes
The following optional properties may be specified in the `memory_sizes` mapping.

| Name | Description
| ---- | -----------
| `heap` | The maximum heap size to use. It may be a single value such as `64m` or a range of acceptable values such as `128m..256m`. It is used to calculate the value of the Java command line options `-Xmx` and `-Xms`.
| `metaspace` | The maximum Metaspace size to use. It is applicable to versions of OpenJDK from 1.8 onwards. It may be a single value such as `64m` or a range of acceptable values such as `128m..256m`. It is used to calculate the value of the Java command line options `-XX:MaxMetaspaceSize=` and `-XX:MetaspaceSize=`.
| `native` | The amount of memory to reserve for native memory allocation. It should normally be omitted or specified as a range with no upper bound such as `100m..`. It does not correspond to a switch on the Java command line.
| `permgen` | The maximum PermGen size to use. It is applicable to versions of OpenJDK earlier than 1.8. It may be a single value such as `64m` or a range of acceptable values such as `128m..256m`. It is used to calculate the value of the Java command line options `-XX:MaxPermSize=` and `-XX:PermSize=`.
| `stack` | The stack size to use. It may be a single value such as `2m` or a range of acceptable values such as `2m..4m`. It is used to calculate the value of the Java command line option `-Xss`.

Memory sizes together with _memory weightings_ (described in the next section) are used to calculate the amount of memory for each memory type. The calculation is described later.

Memory sizes consist of a non-negative integer followed by a unit (`k` for kilobytes, `m` for megabytes, `g` for gigabytes; the case is not significant). Only the memory size `0` may be specified without a unit.

The above memory size properties may be omitted with an empty value, specified as a single value, or specified as a range. Ranges use the syntax `<lower bound>..<upper bound>`, although either bound may be omitted in which case the defaults of zero and the total available memory are used for the lower bound and upper bound, respectively. Examples of ranges are `100m..200m` (any value between 100 and 200 megabytes, inclusive) and `100m..` (any value greater than or equal to 100 megabytes).

Each form of memory size is equivalent to a range. Omitting a memory size is equivalent to specifying the range `0..`. Specifying a single value is equivalent to specifying the range with that value as both the lower and upper bound, for example `128m` is equivalent to the range `128m..128m`.

#### Memory Weightings
Memory weightings are configured in the `memory_heuristics` mapping of [`config/open_jdk_jre.yml`][]. Each weighting is a non-negative number and represents a proportion of the total available memory (represented by the sum of all the weightings). For example, the following weightings:

```yaml
memory_heuristics:
  heap: 15
  native: 2
  permgen: 5
  stack: 1
```

represent a maximum heap size three times as large as the maximum PermGen size, and so on.

Memory weightings are used together with memory ranges to calculate the amount of memory for each memory type, as follows.

#### Memory Initials
Memory initials are configured in the `memory_initials` mapping of [`config/open_jdk_jre.yml`][]. Each initial is a percentage of the given type of memory. Valid memory types are `heap`, `permgen`, and `metaspace`. For example, the following initials:

```yaml
memory_initials:
  heap: 50%
  permgen: 25%
```

Given a maximum heap (Xmx) of 1G and a maximum permgen (-XX:MaxPermsize) of 256M an initial heap (Xms) of 512M and an initial permgen (-XX:Permsize) of 64M would be used.

If no initial value is specified for a memory type the JVM default will be used.

A value of 100% for each memory types is generally recommended for best performance.  Smaller values will potentially preserve unused system memory for other tenants on the same host.  Using the G1 garbage collector along with aggressive `MinHeapFreeRatio` and `MaxHeapFreeRatio` values the JVM will actually release unused heap back to the system up to the initial value.

#### Stack Threads

The amount of memory that should be allocated to the stack is given as an amount of memory per thread with the command line option `-Xss`. The default behaviour is to use an estimate of the number of threads based on the total memory for the application. If an explicit number of threads should be used for the calculation of stack memory then it should be specified like the following example:

```yaml
stack_threads: 500
```

#### Memory Calculation
Memory calculation happens before every `start` of an application and is performed by an external program, the [Java Buildpack Memory Calculator]. There is no need to `restage` an application after scaling the memory as restarting will cause the memory settings to be recalculated.

The total available memory is allocated into heap, Metaspace or PermGen (depending on the version of Oracle), stack, and native memory types.

The total available memory is first allocated to each memory type in proportion to its weighting (this is called ‘balancing'). If the resultant size of any memory type lies outside its range, the size is constrained to the range, the constrained size is excluded from the remaining memory, and no further calculation is required for that memory type. The remaining memory is then balanced against the memory types that are left, and the check is repeated until no calculated memory sizes lie outside their ranges. The remaining memory is then allocated to the remaining memory types according to the last balance step. This iteration terminates when none of the sizes of the remaining memory types is constrained by their corresponding ranges.

Termination is guaranteed since there is a finite number of memory types and in each iteration either none of the remaining memory sizes is constrained by the corresponding range and allocation terminates or at least one memory size is constrained by the corresponding range and is omitted from the next iteration.

[`config/open_jdk_jre.yml`]: ../config/open_jdk_jre.yml
[Configuration and Extension]: ../README.md#configuration-and-extension
[Java Buildpack Memory Calculator]: https://github.com/cloudfoundry/java-buildpack-memory-calculator
[mountainlion]: http://download.pivotal.io.s3.amazonaws.com/openjdk/mountainlion/x86_64/index.yml
[OpenJDK]: http://openjdk.java.net
[precise]: http://download.pivotal.io.s3.amazonaws.com/openjdk/precise/x86_64/index.yml
[repositories]: extending-repositories.md
[trusty]: http://download.pivotal.io.s3.amazonaws.com/openjdk/trusty/x86_64/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
