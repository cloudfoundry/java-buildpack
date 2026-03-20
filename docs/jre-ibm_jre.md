# IBM Semeru JRE

The IBM Semeru JRE provides Java runtimes built on Eclipse OpenJ9 from IBM. This includes both IBM Semeru Runtime Open Edition (free) and IBM Semeru Runtime Certified Edition (commercial). No versions of the JRE are available by default. You must add IBM Semeru entries to the buildpack's `manifest.yml` file.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Configured via <code>JBP_CONFIG_IBM_JRE</code> environment variable.
      <ul>
        <li>Existence of a Volume Service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service whose name, label or tag has <code>heap-dump</code> as a substring.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>ibm=&lang;version&rang;, open-jdk-like-memory-calculator=&lang;version&rang;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script.

## Setup Requirements

To use IBM Semeru JRE, you must:

1. **Fork the buildpack** and add IBM Semeru entries to `manifest.yml`
2. **Package and upload** your custom buildpack to Cloud Foundry
3. **Configure your application** to use IBM Semeru

For complete step-by-step instructions, see the [Custom JRE Usage Guide](custom-jre-usage.md).

## Adding IBM Semeru to manifest.yml

Add the following to your forked buildpack's `manifest.yml`:

```yaml
# Add to url_to_dependency_map section:
url_to_dependency_map:
  - match: ibm-semeru-open-jre_x64_linux_(\d+\.\d+\.\d+)
    name: ibm
    version: $1

# Add to default_versions section:
default_versions:
  - name: ibm
    version: 17.x

# Add to dependencies section:
dependencies:
  # IBM Semeru Runtime Open Edition 11
  - name: ibm
    version: 11.0.25
    uri: https://github.com/ibmruntimes/semeru11-binaries/releases/download/jdk-11.0.25%2B9_openj9-0.48.0/ibm-semeru-open-jre_x64_linux_11.0.25_9_openj9-0.48.0.tar.gz
    sha256: <calculate-sha256-of-downloaded-file>
    cf_stacks:
      - cflinuxfs4

  # IBM Semeru Runtime Open Edition 17
  - name: ibm
    version: 17.0.13
    uri: https://github.com/ibmruntimes/semeru17-binaries/releases/download/jdk-17.0.13%2B11_openj9-0.48.0/ibm-semeru-open-jre_x64_linux_17.0.13_11_openj9-0.48.0.tar.gz
    sha256: <calculate-sha256-of-downloaded-file>
    cf_stacks:
      - cflinuxfs4

  # IBM Semeru Runtime Open Edition 21
  - name: ibm
    version: 21.0.5
    uri: https://github.com/ibmruntimes/semeru21-binaries/releases/download/jdk-21.0.5%2B11_openj9-0.48.0/ibm-semeru-open-jre_x64_linux_21.0.5_11_openj9-0.48.0.tar.gz
    sha256: <calculate-sha256-of-downloaded-file>
    cf_stacks:
      - cflinuxfs4
```

### Calculating SHA256

```bash
# Download the JRE
curl -LO "https://github.com/ibmruntimes/semeru17-binaries/releases/download/jdk-17.0.13%2B11_openj9-0.48.0/ibm-semeru-open-jre_x64_linux_17.0.13_11_openj9-0.48.0.tar.gz"

# Calculate SHA256
sha256sum ibm-semeru-open-jre_x64_linux_17.0.13_11_openj9-0.48.0.tar.gz
```

### IBM Semeru Download URLs

IBM Semeru Runtime Open Edition downloads are available at:
- **Java 11**: [semeru11-binaries releases](https://github.com/ibmruntimes/semeru11-binaries/releases)
- **Java 17**: [semeru17-binaries releases](https://github.com/ibmruntimes/semeru17-binaries/releases)
- **Java 21**: [semeru21-binaries releases](https://github.com/ibmruntimes/semeru21-binaries/releases)
- **IBM Developer**: [IBM Semeru Downloads](https://developer.ibm.com/languages/java/semeru-runtimes/downloads/)

## Configuration

After adding IBM Semeru to your buildpack's manifest, configure your application:

```bash
# Push with your custom buildpack
cf push my-app -b my-custom-java-buildpack

# Select IBM Semeru JRE
cf set-env my-app JBP_CONFIG_IBM_JRE '{jre: {version: 17.+}}'

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
      JBP_CONFIG_IBM_JRE: '{jre: {version: 17.+}}'
```

## Configuration Options

| Name | Description |
| ---- | ----------- |
| `JBP_CONFIG_IBM_JRE` | Configuration for IBM Semeru JRE, including version selection (e.g., `'{jre: {version: 17.+}}'`). |

### TLS Options

For IBM Semeru/OpenJ9, it is recommended to use the following TLS options:

```bash
cf set-env my-app JAVA_OPTS '-Dcom.ibm.jsse2.overrideDefaultTLS=true'
```

### Custom CA Certificates

**Recommended approach:** Use [Cloud Foundry Trusted System Certificates](https://docs.cloudfoundry.org/devguide/deploy-apps/trusted-system-certificates.html). Operators deploy trusted certificates that are automatically available in `/etc/cf-system-certificates` and `/etc/ssl/certs`.

## OpenJ9 Features

IBM Semeru Runtime uses the Eclipse OpenJ9 JVM, which provides:

- **Shared Class Cache**: Faster startup times through class data sharing
- **Lower Memory Footprint**: Optimized for container environments
- **Pause-less GC Options**: Metronome and Balanced GC policies

For OpenJ9-specific tuning options, see the [OpenJ9 Documentation](https://eclipse.dev/openj9/docs/).

## Memory

The total available memory for the application's container is specified when an application is pushed. The Java buildpack uses this value to control the JRE's use of various regions of memory and logs the JRE memory settings when the application starts or restarts.

Note: If the total available memory is scaled up or down, the Java buildpack will re-calculate the JRE memory settings the next time the application is started.

### Total Memory

The user can change the container's total memory available to influence the JRE memory settings. Unless the user specifies the heap size Java option (`-Xmx`), increasing or decreasing the total memory available results in the heap size setting increasing or decreasing by a corresponding amount.

### Memory Calculation

The buildpack calculates the `-Xmx` memory setting based on the total memory available and the configured heap ratio.

The container's total memory is logged during `cf push` and `cf scale`:

```
     state     since                    cpu    memory       disk         details
#0   running   2017-04-10 02:20:03 PM   0.0%   896K of 1G   1.3M of 1G
```

## License

IBM Semeru Runtime Open Edition is available under the [IBM International License Agreement for Non-Warranted Programs][].

For IBM Semeru Runtime Certified Edition (commercial support), see [IBM product terms](https://www.ibm.com/terms).

## See Also

- [Custom JRE Usage Guide](custom-jre-usage.md) - Complete instructions for adding BYOL JREs
- [OpenJDK JRE](jre-open_jdk_jre.md) - Default JRE (no configuration required)
- [Eclipse OpenJ9 Documentation](https://eclipse.dev/openj9/docs/)
- [IBM Knowledge Center][]

[Configuration and Extension]: ../README.md#configuration-and-extension
[Custom JRE Usage Guide]: custom-jre-usage.md
[IBM International License Agreement for Non-Warranted Programs]: http://www14.software.ibm.com/cgi-bin/weblap/lap.pl?la_formnum=&li_formnum=L-PMAA-A3Z8P2&title=IBM%AE+SDK%2C+Java%99+Technology+Edition%2C+Version+8.0&l=en
[IBM Knowledge Center]: http://www.ibm.com/support/knowledgecenter/SSYKE2/welcome_javasdk_family.html
[Volume Service]: https://docs.cloudfoundry.org/devguide/services/using-vol-services.html
