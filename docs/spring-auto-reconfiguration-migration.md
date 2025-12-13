# Migration Guide: Spring Auto-reconfiguration to java-cfenv

This guide provides step-by-step instructions for migrating from the deprecated **Spring Auto-reconfiguration** framework to **java-cfenv**.

---

## Table of Contents

1. [Why Migrate?](#why-migrate)
2. [What Changes?](#what-changes)
3. [Migration Steps](#migration-steps)
4. [Service-Specific Migration](#service-specific-migration)
5. [Testing Your Migration](#testing-your-migration)
6. [Troubleshooting](#troubleshooting)
7. [Rollback Plan](#rollback-plan)

---

## Why Migrate?

**Spring Auto-reconfiguration is deprecated** and disabled by default as of December 2025 because:

1. **Spring Cloud Connectors** (the underlying library) entered maintenance mode in July 2019
2. **No security updates** or bug fixes will be provided
3. **Not compatible** with Spring Boot 3.x
4. **java-cfenv** is the official replacement recommended by Pivotal/VMware

**Timeline**:
- **July 2019**: Spring Cloud Connectors deprecated
- **December 2025**: Spring Auto-reconfiguration disabled by default
- **Future**: Spring Auto-reconfiguration will be removed entirely

---

## What Changes?

### Spring Auto-reconfiguration (Old)

```xml
<!-- Automatically added by buildpack - NO CODE CHANGES NEEDED -->
<!-- Automatically reconfigures DataSource, MongoDB, Redis, etc. -->
```

**How it worked**:
- Buildpack injected `spring-cloud-cloudfoundry-connector` at runtime
- Automatically replaced Spring beans with Cloud Foundry-bound services
- No application code changes required

### java-cfenv (New)

```xml
<!-- Add to your pom.xml -->
<dependency>
    <groupId>io.pivotal.cfenv</groupId>
    <artifactId>java-cfenv-boot</artifactId>
    <version>3.1.4</version>
</dependency>
```

**How it works**:
- You add `java-cfenv` dependency to your application
- Library reads `VCAP_SERVICES` and sets Spring Boot properties
- Spring Boot autoconfiguration uses these properties
- More transparent and Spring Boot native

---

## Migration Steps

### Step 1: Verify Your Spring Boot Version

java-cfenv requires **Spring Boot 2.1+** (Spring Boot 3.x recommended).

Check your `pom.xml` or `build.gradle`:

```xml
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.2.0</version> <!-- Must be 2.1+ -->
</parent>
```

**If you're on Spring Boot 1.x**: Upgrade to Spring Boot 2.x or 3.x first.

---

### Step 2: Add java-cfenv Dependency

#### Maven (pom.xml)

```xml
<dependencies>
    <!-- Add this dependency -->
    <dependency>
        <groupId>io.pivotal.cfenv</groupId>
        <artifactId>java-cfenv-boot</artifactId>
        <version>3.1.4</version>
    </dependency>
</dependencies>
```

#### Gradle (build.gradle)

```groovy
dependencies {
    implementation 'io.pivotal.cfenv:java-cfenv-boot:3.1.4'
}
```

**Note**: Check for the latest version at https://github.com/pivotal-cf/java-cfenv

---

### Step 3: Remove Spring Cloud Connectors (if explicitly added)

If you previously added Spring Cloud Connectors manually, remove them:

#### Remove from Maven (pom.xml)

```xml
<!-- REMOVE THESE if present -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-spring-service-connector</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-cloudfoundry-connector</artifactId>
</dependency>
```

#### Remove from Gradle (build.gradle)

```groovy
// REMOVE THESE if present
implementation 'org.springframework.cloud:spring-cloud-spring-service-connector'
implementation 'org.springframework.cloud:spring-cloud-cloudfoundry-connector'
```

---

### Step 4: Review Custom Service Configurations

If you have custom `@Bean` configurations for services, you may need to update them.

#### Before (Spring Cloud Connectors)

```java
@Configuration
public class CloudConfig extends AbstractCloudConfig {
    
    @Bean
    public DataSource dataSource() {
        return connectionFactory().dataSource();
    }
}
```

#### After (java-cfenv)

**Option 1**: Remove custom configuration (let Spring Boot autoconfigure)

```java
// No configuration needed! 
// java-cfenv sets spring.datasource.url automatically
// Spring Boot autoconfiguration creates DataSource
```

**Option 2**: Keep custom configuration, use environment properties

```java
@Configuration
public class DataSourceConfig {
    
    @Bean
    public DataSource dataSource(
        @Value("${spring.datasource.url}") String url,
        @Value("${spring.datasource.username}") String username,
        @Value("${spring.datasource.password}") String password) {
        
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl(url);
        config.setUsername(username);
        config.setPassword(password);
        return new HikariDataSource(config);
    }
}
```

---

### Step 5: Disable Spring Auto-reconfiguration (if enabled)

If you previously enabled Spring Auto-reconfiguration, remove the environment variable:

```bash
# Remove this environment variable
cf unset-env my-app JBP_CONFIG_SPRING_AUTO_RECONFIGURATION
```

Or ensure your `manifest.yml` doesn't have:

```yaml
env:
  # REMOVE THIS LINE
  JBP_CONFIG_SPRING_AUTO_RECONFIGURATION: '{enabled: true}'
```

---

### Step 6: Update Your Application

```bash
# Build your application with the new dependency
./mvnw clean package

# Push to Cloud Foundry
cf push my-app

# Check logs to verify java-cfenv is loaded
cf logs my-app --recent | grep java-cf-env
```

You should see:

```
Java Buildpack v1.x.x | https://github.com/cloudfoundry/java-buildpack
-----> Supplying frameworks...
       java-cf-env=3.1.4
```

---

## Service-Specific Migration

### PostgreSQL / MySQL / SQL Server

**Spring Auto-reconfiguration** (automatic):
- Automatically created `DataSource` bean

**java-cfenv** (automatic):
- Sets `spring.datasource.url`, `spring.datasource.username`, `spring.datasource.password`
- Spring Boot autoconfiguration creates `DataSource`

**Migration**: No code changes needed! Just add the dependency.

---

### MongoDB

**Spring Auto-reconfiguration**:
```java
// Automatically created MongoClient bean
```

**java-cfenv**:
```properties
# Automatically sets:
# spring.data.mongodb.uri=mongodb://...
```

**Migration**: No code changes needed! Spring Boot autoconfiguration handles it.

---

### Redis

**Spring Auto-reconfiguration**:
```java
// Automatically created RedisConnectionFactory bean
```

**java-cfenv**:
```properties
# Automatically sets:
# spring.data.redis.host=...
# spring.data.redis.port=...
# spring.data.redis.password=...
```

**Migration**: No code changes needed!

---

### RabbitMQ

**Spring Auto-reconfiguration**:
```java
// Automatically created ConnectionFactory bean
```

**java-cfenv**:
```properties
# Automatically sets:
# spring.rabbitmq.host=...
# spring.rabbitmq.port=...
# spring.rabbitmq.username=...
# spring.rabbitmq.password=...
```

**Migration**: No code changes needed!

---

### Custom User-Provided Services

If you're using user-provided services (`cf cups`), you may need to access them manually.

**java-cfenv API**:

```java
import io.pivotal.cfenv.core.CfEnv;
import io.pivotal.cfenv.core.CfService;

@Configuration
public class CustomServiceConfig {
    
    @Bean
    public MyCustomService customService() {
        CfEnv cfEnv = new CfEnv();
        CfService service = cfEnv.findServiceByName("my-custom-service");
        
        String url = service.getCredentials().getString("url");
        String apiKey = service.getCredentials().getString("api_key");
        
        return new MyCustomService(url, apiKey);
    }
}
```

---

## Testing Your Migration

### 1. Local Testing (without Cloud Foundry)

java-cfenv gracefully handles missing `VCAP_SERVICES`:

```bash
# Run locally - uses application.properties
./mvnw spring-boot:run
```

Your local `application.properties` will be used as normal.

---

### 2. Cloud Foundry Testing

```bash
# Push to CF
cf push my-app

# Check that services are bound
cf services

# Verify environment
cf env my-app | grep VCAP_SERVICES

# Check logs for java-cfenv
cf logs my-app --recent | grep "java-cf-env"

# Test application endpoints
curl https://my-app.example.com/health
```

---

### 3. Verify Service Connections

Add this debug endpoint to verify connections:

```java
@RestController
public class DebugController {
    
    @Autowired
    private DataSource dataSource;
    
    @GetMapping("/debug/datasource")
    public String testDataSource() throws Exception {
        try (Connection conn = dataSource.getConnection()) {
            return "Database connected: " + conn.getMetaData().getURL();
        }
    }
}
```

---

## Troubleshooting

### Issue: "No suitable driver found"

**Cause**: Missing JDBC driver dependency

**Solution**: Add the appropriate driver:

```xml
<!-- PostgreSQL -->
<dependency>
    <groupId>org.postgresql</groupId>
    <artifactId>postgresql</artifactId>
</dependency>

<!-- MySQL -->
<dependency>
    <groupId>com.mysql</groupId>
    <artifactId>mysql-connector-j</artifactId>
</dependency>
```

---

### Issue: Application can't find services

**Cause**: Service not bound to application

**Solution**: Verify service binding:

```bash
cf services
cf bind-service my-app my-database
cf restage my-app
```

---

### Issue: Custom properties not being set

**Cause**: java-cfenv may not support your service type

**Solution**: Use the `CfEnv` API to manually extract credentials:

```java
import io.pivotal.cfenv.core.CfEnv;

@Configuration
public class CustomConfig {
    
    @Bean
    public MyService myService() {
        CfEnv cfEnv = new CfEnv();
        CfService service = cfEnv.findServiceByLabel("my-service-type");
        // Extract credentials manually
        return new MyService(service.getCredentials());
    }
}
```

---

### Issue: "cloud" profile not active

**Cause**: java-cfenv only activates "cloud" profile on Cloud Foundry

**Solution**: This is expected. Locally, the "cloud" profile won't be active.

To test cloud profile locally:

```bash
java -jar myapp.jar --spring.profiles.active=cloud
```

---

## Rollback Plan

If you encounter issues and need to rollback:

### Step 1: Re-enable Spring Auto-reconfiguration

```bash
cf set-env my-app JBP_CONFIG_SPRING_AUTO_RECONFIGURATION '{enabled: true}'
cf restage my-app
```

### Step 2: Remove java-cfenv dependency (optional)

You can leave java-cfenv in place - it won't conflict with Spring Auto-reconfiguration.

### Step 3: Report Issues

If you encounter migration issues:

1. Check buildpack logs: `cf logs my-app --recent`
2. Report issues to: https://github.com/cloudfoundry/java-buildpack/issues
3. For java-cfenv issues: https://github.com/pivotal-cf/java-cfenv/issues

---

## Additional Resources

- **java-cfenv Repository**: https://github.com/pivotal-cf/java-cfenv
- **java-cfenv Documentation**: https://github.com/pivotal-cf/java-cfenv/blob/main/README.md
- **Spring Boot on Cloud Foundry**: https://docs.spring.io/spring-boot/docs/current/reference/html/deployment.html#deployment.cloud.cloudfoundry
- **Cloud Foundry Java Buildpack**: https://github.com/cloudfoundry/java-buildpack

---

## Summary Checklist

- [ ] Verify Spring Boot version (2.1+ required, 3.x recommended)
- [ ] Add `java-cfenv-boot` dependency to `pom.xml` or `build.gradle`
- [ ] Remove Spring Cloud Connectors dependencies (if present)
- [ ] Review and simplify custom service configurations
- [ ] Remove `JBP_CONFIG_SPRING_AUTO_RECONFIGURATION` environment variable
- [ ] Build and test locally
- [ ] Deploy to Cloud Foundry
- [ ] Verify services are connected
- [ ] Test application functionality
- [ ] Monitor logs for errors

---

**Migration complete!** Your application now uses the modern, supported java-cfenv library.

If you have questions or issues, please consult the [java-cfenv documentation](https://github.com/pivotal-cf/java-cfenv) or file an issue on the [Java Buildpack repository](https://github.com/cloudfoundry/java-buildpack/issues).
