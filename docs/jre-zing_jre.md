# Azul Platform Prime JRE

Azul Platform Prime (formerly Zing) provides high-performance Java runtimes from [Azul][]. No versions of the JRE are available by default due to licensing restrictions. You must add Azul Platform Prime JRE entries to the buildpack's `manifest.yml` file.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Configured via <code>JBP_CONFIG_ZING_JRE</code> environment variable.
      <ul>
        <li>Existence of a Volume Service service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service whose name, label or tag has <code>heap-dump</code> as a substring.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>zing=&lang;version&rang;, open-jdk-like-memory-calculator=&lang;version&rang;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script.

## Setup Requirements

To use Azul Platform Prime JRE, you must:

1. **Fork the buildpack** and add Azul Platform Prime JRE entries to `manifest.yml`
2. **Package and upload** your custom buildpack to Cloud Foundry
3. **Configure your application** to use the Azul Platform Prime JRE

For complete step-by-step instructions, see the [Custom JRE Usage Guide](custom-jre-usage.md).

## Adding Azul Platform Prime JRE to manifest.yml

Add the following to your forked buildpack's `manifest.yml`:

```yaml
# Add to url_to_dependency_map section:
url_to_dependency_map:
  - match: zing(\d+\.\d+\.\d+\.\d+)-\d+-ca-jdk(\d+\.\d+\.\d+)-linux_x64\.tar\.gz
    name: zing
    version: $2

# Add to default_versions section:
default_versions:
  - name: zing
    version: 21.x

# Add to dependencies section:
dependencies:
  # Azul Platform Prime JDK 17
  - name: zing
    version: 17.0.13
    uri: https://cdn.azul.com/zing-zvm/feature-preview/zing24.10.0.0-3-ca-jdk17.0.13-linux_x64.tar.gz
    sha256: <calculate-sha256-of-downloaded-file>
    cf_stacks:
      - cflinuxfs4

  # Azul Platform Prime JDK 21
  - name: zing
    version: 21.0.5
    uri: https://cdn.azul.com/zing-zvm/feature-preview/zing24.10.0.0-3-ca-jdk21.0.5-linux_x64.tar.gz
    sha256: <calculate-sha256-of-downloaded-file>
    cf_stacks:
      - cflinuxfs4
```

### Calculating SHA256

```bash
# Download the JDK
curl -LO https://cdn.azul.com/zing-zvm/feature-preview/zing24.10.0.0-3-ca-jdk17.0.13-linux_x64.tar.gz

# Calculate SHA256
sha256sum zing24.10.0.0-3-ca-jdk17.0.13-linux_x64.tar.gz
```

### Azul Platform Prime Download URLs

Azul Platform Prime downloads require an Azul account and license. Contact Azul for access:
- **Azul Platform Prime Downloads**: [https://www.azul.com/downloads/prime/](https://www.azul.com/downloads/prime/)
- **Contact Azul**: [https://www.azul.com/contact-us/](https://www.azul.com/contact-us/)

The URL patterns typically follow:
- `https://cdn.azul.com/zing-zvm/feature-preview/zing<zing-version>-ca-jdk<jdk-version>-linux_x64.tar.gz`

## Configuration

After adding Azul Platform Prime JRE to your buildpack's manifest, configure your application:

```bash
# Push with your custom buildpack
cf push my-app -b my-custom-java-buildpack

# Select Azul Platform Prime JRE
cf set-env my-app JBP_CONFIG_ZING_JRE '{jre: {version: 21.+}}'

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
      JBP_CONFIG_ZING_JRE: '{jre: {version: 21.+}}'
```

## Configuration Options

| Name | Description |
| ---- | ----------- |
| `JBP_CONFIG_ZING_JRE` | Configuration for Azul Platform Prime JRE, including version selection (e.g., `'{jre: {version: 21.+}}'`). |

### Memory Configuration

Memory settings are configured via the memory calculator. See [Memory Configuration](#memory) below.

### Custom CA Certificates

**Recommended approach:** Use [Cloud Foundry Trusted System Certificates](https://docs.cloudfoundry.org/devguide/deploy-apps/trusted-system-certificates.html). Operators deploy trusted certificates that are automatically available in `/etc/cf-system-certificates` and `/etc/ssl/certs`.

## JVMKill / Out of Memory Handling

Azul Platform Prime JRE does not use the jvmkill agent. Instead, it uses the `-XX:ExitOnOutOfMemoryError` flag by default, which terminates the JVM process when an out-of-memory error occurs.

If a [Volume Service][] with the string `heap-dump` in its name or tag is bound to the application, terminal heap dumps will be written with the pattern `<CONTAINER_DIR>/<SPACE_NAME>-<SPACE_ID[0,8]>/<APPLICATION_NAME>-<APPLICATION_ID[0,8]>/<INSTANCE_INDEX>-<TIMESTAMP>-<INSTANCE_ID[0,8]>.hprof`

```plain
Heapdump written to /var/vcap/data/9ae0b817-1446-4915-9990-74c1bb26f147/pcfdev-space-e91c5c39/java-main-application-892f20ab/0-2017-06-13T18:31:29+0000-7b23124e.hprof
```

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

## Azul Platform Prime Features

Azul Platform Prime includes advanced features beyond standard OpenJDK:

- **ReadyNow!**: Eliminates JVM warm-up time through persistent compilation profiles
- **Falcon JIT Compiler**: LLVM-based JIT compiler for better peak performance
- **C4 Garbage Collector**: Pauseless garbage collection for low-latency applications
- **Optimizer Hub**: Cloud-based compilation optimization (requires separate configuration)

Refer to [Azul Platform Prime documentation](https://docs.azul.com/prime/) for feature configuration.

## See Also

- [Custom JRE Usage Guide](custom-jre-usage.md) - Complete instructions for adding BYOL JREs
- [OpenJDK JRE](jre-open_jdk_jre.md) - Default JRE (no configuration required)
- [Azul Zulu JRE](jre-zulu_jre.md) - Azul's OpenJDK-based offering (included in manifest)

[Azul]: https://www.azul.com/products/prime/
[Configuration and Extension]: ../README.md#configuration-and-extension
[Custom JRE Usage Guide]: custom-jre-usage.md
[Java Buildpack Memory Calculator]: https://github.com/cloudfoundry/java-buildpack-memory-calculator
[Volume Service]: https://docs.cloudfoundry.org/devguide/services/using-vol-services.html
