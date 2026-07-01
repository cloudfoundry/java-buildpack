# Java CfEnv Framework
The Java CfEnv Framework provides the `java-cfenv` library for Spring Boot 3.x and 4.x applications. This library sets various Spring Boot properties by parsing CloudFoundry variables such as `VCAP_SERVICES`, allowing Spring Boot's autoconfiguration to kick in.

This is the recommended replacement for Spring AutoReconfiguration library which is deprecated. See the `java-cfenv` <a href="https://github.com/pivotal-cf/java-cfenv">repository</a> for more detail.

The included `java-cfenv` library activates the `cloud` Spring profile at runtime when `VCAP_SERVICES` is present, as the Spring AutoReconfiguration framework did. The buildpack itself does not set any Spring profile.

The buildpack selects the appropriate `java-cfenv` version based on the detected Spring Boot major version:

| Spring Boot | java-cfenv |
|-------------|------------|
| 3.x | 3.x (latest) |
| 4.x | 4.x (latest) |

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a <tt>spring-boot-3.*.jar</tt> or <tt>spring-boot-4.*.jar</tt> in <tt>BOOT-INF/lib</tt>, <tt>WEB-INF/lib</tt>, or <tt>lib/</tt>; or a <tt>Spring-Boot-Version: 3.*</tt> / <tt>Spring-Boot-Version: 4.*</tt> entry in <tt>META-INF/MANIFEST.MF</tt></td>
    <td>No existing <tt>java-cfenv</tt> library found in the application</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>java-cf-env=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration

The framework can be disabled via the `JBP_CONFIG_JAVA_CF_ENV` environment variable:

```bash
cf set-env <app> JBP_CONFIG_JAVA_CF_ENV '{enabled: false}'
```

To re-enable, either set it back to `{enabled: true}` or remove the variable entirely:

```bash
cf unset-env <app> JBP_CONFIG_JAVA_CF_ENV
```

| Variable | Default | Description |
|----------|---------|-------------|
| `JBP_CONFIG_JAVA_CF_ENV` | `{enabled: true}` | Enable or disable the framework |

Note: if `java-cfenv*.jar` is already present in the application, the buildpack skips injection automatically — no need to disable explicitly for that case.

Disable when:
- The application handles `VCAP_SERVICES` manually with custom binding logic
- The automatic `cloud` profile activation is unwanted
- Another service binding library conflicts with `java-cfenv`