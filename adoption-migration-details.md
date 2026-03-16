# Java Buildpack Migration: Adoption and Migration Details

## Overview

The Go-based Java Buildpack introduces changes to default versions that may affect legacy applications. This document provides guidance on understanding these changes and migrating your applications smoothly.

## Default Version Changes

### Ruby-based Buildpack Defaults
- **Java Version**: OpenJDK JRE 1.8.0_x
- **Tomcat Version**: Tomcat 9.0.x

### Go-based Buildpack Defaults
- **Java Version**: OpenJDK JRE 17.x
- **Tomcat Version**: Tomcat 10.x

## Impact on Legacy Applications

If your application does not explicitly specify Java or Tomcat versions in its `manifest.yml`, the new defaults will apply after redeploying or restaging your application. This change can cause potential issues for legacy applications, particularly:

### Tomcat 9 to Tomcat 10 Migration

The migration from Tomcat 9 to Tomcat 10 will likely require code modifications in your application due to the namespace change from `javax.*` to `jakarta.*`.

**Important Note**: Users of Tomcat 10 onwards should be aware that, as a result of the move from Java EE to Jakarta EE as part of the transfer of Java EE to the Eclipse Foundation, the primary package for all implemented APIs has changed from `javax.*` to `jakarta.*`. This will almost certainly require code changes to enable applications to migrate from Tomcat 9 and earlier to Tomcat 10 and later.

A [migration tool](https://github.com/apache/tomcat-jakartaee-migration) has been developed to aid this process.

### Java 8 to Java 17 Migration

Applications compiled with Java 8 should generally run on Java 17 without issues, as Java versions are backward compatible. However, there are edge cases to consider (see Adoption/Migration Details below).

## When Changes Take Effect

**Important**: If you haven't explicitly set Tomcat or Java versions, your applications are currently using the Ruby-based buildpack defaults:
- Tomcat 9 by default
- Java 1.8.x by default

**Starting with the Go-based Java Buildpack, they will be switched to:**
- Tomcat 10
- Java 17

**This change will take effect only after redeploy or restage.**

## How to Maintain Current Versions

If you want to continue using your current versions until their End-of-Life (EOL) dates, you need to explicitly specify them in your configuration files.

### Specifying Tomcat Version

To continue using Tomcat 9, add the following to your `manifest.yml`:

```yaml
env:
  JBP_CONFIG_TOMCAT: '{ tomcat: { version: "9.+" } }'
```

### Specifying Java Version

To continue using an older Java version (e.g., Java 11), add the following to your `manifest.yml`:

```yaml
env:
  JBP_CONFIG_OPEN_JDK_JRE: '{ jre: { version: 11.+ } }'
```

## Breaking Changes

This section highlights significant breaking changes introduced in the Go-based Java Buildpack.

### Custom JRE Usage

Custom JRE usage will be supported only as documented in the [Custom JRE Usage Guide](custom-jre-usage.md).

### Changed Default Configuration

- **SpringAutoReconfigurationFramework is now disabled by default.** Please note that `SpringAutoReconfigurationFramework` is deprecated, and the recommended alternative is [java-cfenv](https://github.com/pivotal-cf/java-cfenv).
- **JRE selection based on `JBP_CONFIG_COMPONENTS` is deprecated.** The Go-based buildpack supports JRE selection based on `JBP_CONFIG_<JRE_TYPE>` as described in the [README](https://github.com/cloudfoundry/java-buildpack/blob/feature/go-migration/README.md#jre-selection).

### Frameworks Not Included

The following frameworks will not be migrated to the Go buildpack:

- **Takipi Agent (OverOps)**: Removed because the agent has moved behind a licensed login wall, making it inaccessible for automated buildpack integration.
- **Java Security**: Rarely used and custom security policies should be implemented at the platform level or within application code.
- **Multi Buildpack**: No longer needed as multi-buildpack support is now built into the `libbuildpack` architecture by default.
- **Spring Insight**: Legacy monitoring tool that has been replaced by modern APM solutions (such as New Relic, AppDynamics, and Dynatrace).
- **Configuration based on resource overlay**: This is more of an anti-pattern and requires a fork of the buildpack.

## Adoption/Migration Details

There are two main aspects to consider when migrating to the Go-based Java Buildpack:

### 1. Migration from Java 8 to Later Java Versions

**Compatibility**: In general, Java versions are backward compatible. Even if an application is compiled with Java 8, it should run on any later version (including Java 17).

**Exceptions**: The main exception is if your application uses internal and/or undocumented Java APIs that might have been removed or changed in later versions. This should be a rather exceptional case.

**Effort Required**: For the vast majority of applications, there should be no effort involved in the Java version migration.

### 2. Migration from Java EE `javax.*` to Jakarta EE `jakarta.*`

**When This Applies**: If your application or its dependencies use any of the former Java EE `javax.*` packages, you will need to migrate to the Jakarta EE `jakarta.*` namespace.

**Migration Approach**: You can choose to use several (semi-)automated tools available to help run the migration. Some of these tools with detailed how-to guides include:

#### Recommended Migration Tools

1. **OpenRewrite** - Automated source code refactoring
   - [Migration Recipe: JavaxMigrationToJakarta](https://docs.openrewrite.org/recipes/java/migrate/jakarta/javaxmigrationtojakarta)
   
2. **Apache Tomcat Migration Tool** - Binary transformation tool
   - [Tomcat Jakarta EE Migration Tool](https://github.com/apache/tomcat-jakartaee-migration)
   
3. **Apache TomEE Migration Guide** - Comprehensive migration guide
   - [TomEE: javax to jakarta Migration](https://tomee.apache.org/javax-to-jakarta.html)

**Testing**: It's always important to thoroughly test your scenarios after the migration to ensure all functionality works as expected.

## Migration Strategy Recommendations

### Option 1: Immediate Migration (Recommended)
1. Review your application code and dependencies for `javax.*` usage
2. Use one of the automated migration tools listed above
3. Thoroughly test your application
4. Deploy using the Go-based buildpack with default settings

### Option 2: Staged Migration
1. **Phase 1**: Explicitly set your current versions in `manifest.yml`:
   ```yaml
   env:
     JBP_CONFIG_TOMCAT: '{ tomcat: { version: "9.+" } }'
     JBP_CONFIG_OPEN_JDK_JRE: '{ jre: { version: 8.+ } }'
   ```
2. **Phase 2**: Upgrade Java version first (if needed), test thoroughly
3. **Phase 3**: Migrate to Jakarta EE namespace, upgrade to Tomcat 10, test thoroughly
4. **Phase 4**: Remove explicit version configurations to use defaults

### Option 3: Maintain Current Versions Until EOL
1. Explicitly set both Tomcat 9 and your current Java version
2. Plan migration before EOL dates
3. Monitor EOL announcements for your versions

## Additional Resources

- [OpenRewrite: JavaxMigrationToJakarta Recipe](https://docs.openrewrite.org/recipes/java/migrate/jakarta/javaxmigrationtojakarta)
- [Apache Tomcat Jakarta EE Migration Tool](https://github.com/apache/tomcat-jakartaee-migration)
- [Apache TomEE: javax to jakarta Migration Guide](https://tomee.apache.org/javax-to-jakarta.html)
- [RFC-0050: Java Buildpack Migration to Golang](https://raw.githubusercontent.com/cloudfoundry/community/refs/heads/main/toc/rfc/rfc-0050-java-buildpack-migration-to-golang.md)

## Support and Feedback

If you encounter issues during migration or have questions:
1. Review the [buildpack documentation](../README.md)
2. Check the [RFC document](https://github.com/cloudfoundry/community/pull/1392) for detailed technical information
3. Open an issue in the [Java Buildpack repository](https://github.com/cloudfoundry/java-buildpack)

## Summary Checklist

Before deploying with the Go-based Java Buildpack:

- [ ] Review your application for `javax.*` package usage
- [ ] Decide on migration strategy (immediate, staged, or maintain current)
- [ ] If maintaining current versions, update `manifest.yml` with explicit version configurations
- [ ] If migrating, choose and run appropriate migration tool
- [ ] Test thoroughly in non-production environment
- [ ] Plan deployment and rollback strategy
- [ ] Monitor application after deployment
