# Java CfEnv Framework
The Java CfEnv Framework provides the `java-cfenv` library for Spring Boot 3.x and 4.x applications. This library sets various Spring Boot properties by parsing Cloud Foundry variables such as `VCAP_SERVICES`, allowing Spring Boot's autoconfiguration to kick in.

This is the recommended replacement for Spring AutoReconfiguration library which is deprecated. See the `java-cfenv` <a href="https://github.com/pivotal-cf/java-cfenv">repository</a> for more details.

The `cloud` Spring profile is activated at runtime by java-cfenv's `CloudProfileApplicationListener`, which ships in the `java-cfenv-all` module. To ensure the profile is active — or to activate it independently of java-cfenv — set it explicitly. Use `SPRING_PROFILES_INCLUDE=cloud` to add `cloud` alongside any other active profiles, or `SPRING_PROFILES_ACTIVE=cloud` to set it as the sole active profile (this replaces any others). The buildpack itself does not set any Spring profile.

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
cf restage <app>
```

The buildpack only re-reads this variable during staging, so a `cf restage` is required for the change to take effect.

To re-enable, either set it back to `{enabled: true}` or remove the variable entirely:

```bash
cf unset-env <app> JBP_CONFIG_JAVA_CF_ENV
cf restage <app>
```

| Variable | Default | Description |
|----------|---------|-------------|
| `JBP_CONFIG_JAVA_CF_ENV` | `{enabled: true}` | Enable or disable the framework |

Note: if `java-cfenv*.jar` is already present in the application, the buildpack skips injection automatically — no need to disable explicitly for that case.

Disable when:
- The application handles `VCAP_SERVICES` manually with custom binding logic
- The automatic `cloud` profile activation is unwanted
- Another service binding library conflicts with `java-cfenv`
