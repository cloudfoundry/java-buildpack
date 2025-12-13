# Spring Auto-reconfiguration Framework

---
## 🛑 CRITICAL DEPRECATION NOTICE 🛑

**THIS FRAMEWORK IS DEPRECATED AND DISABLED BY DEFAULT**

**Status**: Disabled since December 2025  
**Reason**: Spring Cloud Connectors entered maintenance mode in July 2019  
**Action Required**: **MIGRATE TO JAVA-CFENV IMMEDIATELY**

See the **[Migration Guide from Spring Auto-reconfiguration to java-cfenv](spring-auto-reconfiguration-migration.md)** for step-by-step instructions.

---

The Spring Auto-reconfiguration Framework causes an application to be automatically reconfigured to work with configured cloud services.

## Why This Framework is Deprecated

1. **Spring Cloud Connectors is in maintenance mode** (since July 2019)
2. **No security updates or bug fixes** will be provided
3. **Not compatible with modern Spring Boot** (3.x+) 
4. **Replaced by java-cfenv** - the official successor library

## Migration Path

| Your Application | Recommended Action |
|------------------|-------------------|
| **Spring Boot 3.x** | **Migrate to [java-cfenv](framework-java-cfenv.md) NOW** |
| **Spring Boot 2.x** | Plan migration to java-cfenv when upgrading to Spring Boot 3.x |
| **Legacy Spring apps** | Consider upgrading to Spring Boot 3.x + java-cfenv |

**See**: [Complete Migration Guide](spring-auto-reconfiguration-migration.md)

## Re-enabling (NOT RECOMMENDED)

If you absolutely must re-enable this deprecated framework temporarily:

```bash
cf set-env my-app JBP_CONFIG_SPRING_AUTO_RECONFIGURATION '{enabled: true}'
cf restage my-app
```

**⚠️ WARNING**: This is a temporary workaround only. Plan your migration immediately.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a <tt>spring-core*.jar</tt> file in the application directory AND explicitly enabled via configuration</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>spring-auto-reconfiguration=&lt;version&gt;</tt> (only when enabled)</td>
  </tr>
  <tr>
    <td><strong>Default</strong></td>
    <td><strong>DISABLED</strong> (as of Dec 2025)</td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

The Spring Auto-reconfiguration Framework adds the `cloud` profile to any existing Spring profiles such as those defined in the [`SPRING_PROFILES_ACTIVE`][] environment variable.  It also uses the [Spring Cloud Cloud Foundry Connector][] to replace any bean of a candidate type with one mapped to a bound service instance.  Please see the [Auto-Reconfiguration][] project for more details.

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/spring_auto_reconfiguration.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `enabled` | Whether to attempt auto-reconfiguration. **Default: `false`** (disabled since Dec 2025)
| `repository_root` | The URL of the Auto-reconfiguration repository index ([details][repositories]).
| `version` | The version of Auto-reconfiguration to use. Candidate versions can be found in [this listing][].

### Enabling Spring Auto-reconfiguration

To enable this deprecated framework, set the environment variable:

```bash
cf set-env my-app JBP_CONFIG_SPRING_AUTO_RECONFIGURATION '{enabled: true}'
cf restage my-app
```

**Warning**: You will see deprecation warnings in your logs when this framework is enabled.

[Auto-Reconfiguration]: https://github.com/cloudfoundry/java-buildpack-auto-reconfiguration
[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/spring_auto_reconfiguration.yml`]: ../config/spring_auto_reconfiguration.yml
[repositories]: extending-repositories.md
[Spring Cloud Cloud Foundry Connector]: https://cloud.spring.io/spring-cloud-connectors/spring-cloud-cloud-foundry-connector.html
[this listing]: http://download.pivotal.io.s3.amazonaws.com/auto-reconfiguration/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
[`SPRING_PROFILES_ACTIVE`]: http://docs.spring.io/spring/docs/4.0.0.RELEASE/javadoc-api/org/springframework/core/env/AbstractEnvironment.html#ACTIVE_PROFILES_PROPERTY_NAME
