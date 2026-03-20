# Oracle JRE

The Oracle JRE provides Java runtimes from [Oracle][]. No versions of the JRE are available by default due to licensing restrictions. You must add Oracle JRE entries to the buildpack's `manifest.yml` file.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Configured via <code>JBP_CONFIG_ORACLE_JRE</code> environment variable.
      <ul>
        <li>Existence of a Volume Service service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service whose name, label or tag has <code>heap-dump</code> as a substring.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>oracle=&lang;version&rang;, open-jdk-like-memory-calculator=&lang;version&rang;, jvmkill=&lang;version&rang;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script.

## Setup Requirements

To use Oracle JRE, you must:

1. **Fork the buildpack** and add Oracle JRE entries to `manifest.yml`
2. **Package and upload** your custom buildpack to Cloud Foundry
3. **Configure your application** to use the Oracle JRE

For complete step-by-step instructions, see the [Custom JRE Usage Guide](custom-jre-usage.md).

## Adding Oracle JRE to manifest.yml

Add the following to your forked buildpack's `manifest.yml`:

```yaml
# Add to url_to_dependency_map section:
url_to_dependency_map:
  - match: jdk-(\d+\.\d+\.\d+)_linux-x64_bin\.tar\.gz
    name: oracle
    version: $1

# Add to default_versions section:
default_versions:
  - name: oracle
    version: 17.x

# Add to dependencies section:
dependencies:
  # Oracle JDK 17
  - name: oracle
    version: 17.0.13
    uri: https://download.oracle.com/java/17/archive/jdk-17.0.13_linux-x64_bin.tar.gz
    sha256: <calculate-sha256-of-downloaded-file>
    cf_stacks:
      - cflinuxfs4

  # Oracle JDK 21
  - name: oracle
    version: 21.0.5
    uri: https://download.oracle.com/java/21/archive/jdk-21.0.5_linux-x64_bin.tar.gz
    sha256: <calculate-sha256-of-downloaded-file>
    cf_stacks:
      - cflinuxfs4
```

### Calculating SHA256

```bash
# Download the JDK
curl -LO https://download.oracle.com/java/17/archive/jdk-17.0.13_linux-x64_bin.tar.gz

# Calculate SHA256
sha256sum jdk-17.0.13_linux-x64_bin.tar.gz
```

### Oracle Download URLs

Oracle JDK downloads are available at:
- **Java 17**: `https://download.oracle.com/java/17/archive/jdk-17.0.x_linux-x64_bin.tar.gz`
- **Java 21**: `https://download.oracle.com/java/21/archive/jdk-21.0.x_linux-x64_bin.tar.gz`
- **Latest versions**: [Oracle Java Downloads](https://www.oracle.com/java/technologies/downloads/)

## Configuration

After adding Oracle JRE to your buildpack's manifest, configure your application:

```bash
# Push with your custom buildpack
cf push my-app -b my-custom-java-buildpack

# Select Oracle JRE
cf set-env my-app JBP_CONFIG_ORACLE_JRE '{jre: {version: 17.+}}'

# Restage to apply
cf restage my-app
```

Or in your application's `manifest.yml`:

```yaml
applications:
  - name: my-app
    buildpacks:
      - my-custom-java-buildpack
    env:
      JBP_CONFIG_ORACLE_JRE: '{jre: {version: 17.+}}'
```

## Configuration Options

| Name | Description |
| ---- | ----------- |
| `JBP_CONFIG_ORACLE_JRE` | Configuration for Oracle JRE, including version selection (e.g., `'{jre: {version: 17.+}}'`). |

### Memory Configuration

Memory settings are configured via the memory calculator. See [Memory Configuration](#memory) below.

### Custom CA Certificates

**Recommended approach:** Use [Cloud Foundry Trusted System Certificates](https://docs.cloudfoundry.org/devguide/deploy-apps/trusted-system-certificates.html). Operators deploy trusted certificates that are automatically available in `/etc/cf-system-certificates` and `/etc/ssl/certs`.

### JCE Unlimited Strength

Modern Oracle JDK versions (8u161+) include unlimited strength cryptography by default. No additional configuration is required.

## JVMKill Agent

The `jvmkill` agent runs when an application experiences a resource exhaustion event. When this occurs, the agent prints a histogram of the largest types by total bytes:

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

It also prints a summary of JVM memory spaces:

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

## Memory

The total available memory for the application's container is specified when an application is pushed. The Java buildpack uses this value to control the JRE's use of various regions of memory and logs the JRE memory settings when the application starts or restarts.

Note: If the total available memory is scaled up or down, the Java buildpack will re-calculate the JRE memory settings the next time the application is started.

### Total Memory

The user can change the container's total memory available to influence the JRE memory settings. Unless the user specifies the heap size Java option (`-Xmx`), increasing or decreasing the total memory available results in the heap size setting increasing or decreasing by a corresponding amount.

### Loaded Classes

The amount of memory allocated to metaspace and compressed class space is calculated from an estimate of the number of classes that will be loaded. The default behavior is to estimate the number of loaded classes as a fraction of the number of class files in the application. To specify a specific number:

```yaml
class_count: 500
```

### Headroom

A percentage of total memory to leave as headroom:

```yaml
headroom: 10
```

### Stack Threads

The amount of memory for stacks is given as memory per thread with `-Xss`. To specify an explicit thread count:

```yaml
stack_threads: 500
```

Note: The default of 250 threads is optimized for Tomcat. For non-blocking servers like Netty, use a smaller value (typically 25).

### Memory Calculation

Memory calculation happens before every `start` of an application and is performed by the [Java Buildpack Memory Calculator][]. No need to `restage` after scaling memory—restarting recalculates the settings.

The JRE memory settings are logged when the application starts:

```
JVM Memory Configuration: -XX:MaxDirectMemorySize=10M -XX:MaxMetaspaceSize=99199K \
    -XX:ReservedCodeCacheSize=240M -XX:CompressedClassSpaceSize=18134K -Xss1M -Xmx368042K
```

## See Also

- [Custom JRE Usage Guide](custom-jre-usage.md) - Complete instructions for adding BYOL JREs
- [OpenJDK JRE](jre-open_jdk_jre.md) - Default JRE (no configuration required)

[Configuration and Extension]: ../README.md#configuration-and-extension
[Custom JRE Usage Guide]: custom-jre-usage.md
[Java Buildpack Memory Calculator]: https://github.com/cloudfoundry/java-buildpack-memory-calculator
[Oracle]: https://www.oracle.com/java/
[Volume Service]: https://docs.cloudfoundry.org/devguide/services/using-vol-services.html
