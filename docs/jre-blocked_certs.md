# JRE Blocked Certificates
The buildpack adds certificates that OpenJDK has distrusted to the JRE's blocked certificates file at staging time, so they are also blocked by JREs that do not include the OpenJDK change yet. It applies to every JRE.

The certificates are listed in [`src/java/resources/files/jre/blocked.certs`][list] and are added to:

* `lib/security/blocked.certs` (Java 11 and later)
* `lib/security/blacklisted.certs` or `jre/lib/security/blacklisted.certs` (Java 8)

Entries that the JRE already has are kept, and certificates that it already blocks are skipped, so the step does nothing on a JRE that includes the change. When certificates are added, staging logs `Added N certificate(s) to blocked.certs`; otherwise it logs `blocked.certs already contains all blocked certificates`. A JRE that blocks a certificate rejects any TLS connection whose certificate chain contains it, also when the chain is trusted through the [Container Security Provider](framework-container_security_provider.md).

Currently listed:

* eMudhra intermediate CAs (16 certificates), from [openjdk/jdk@22bc7357ce][emudhra] (8395142: CA Enhancements).

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The step can be configured by setting the `JBP_CONFIG_JRE_BLOCKED_CERTS` environment variable. The value must be valid inline YAML.

| Name | Description
| ---- | -----------
| `enabled` | Whether certificates are added to the JRE's blocked certificates file. Defaults to `true`.

### Examples

Disable the step:

```bash
cf set-env my-app JBP_CONFIG_JRE_BLOCKED_CERTS '{enabled: false}'
```

## Adding certificates
Generate the lines with OpenJDK's `BlockedCertsConverter` (`make/jdk/src/classes/build/tools/blockedcertsconverter`), which also adds hashes of alternate encodings of each certificate. Do not hash the certificates yourself. Append the generated fingerprint lines to [the list][list] with a comment naming the source.

```bash
javac --add-exports java.base/sun.security.util=ALL-UNNAMED -d out BlockedCertsConverter.java
{ echo '#! java BlockedCertsConverter SHA-256'; cat certs.pem; } |
  java --add-exports java.base/sun.security.util=ALL-UNNAMED -cp out build.tools.blockedcertsconverter.BlockedCertsConverter
```

[Configuration and Extension]: ../README.md#configuration-and-extension
[emudhra]: https://github.com/openjdk/jdk/commit/22bc7357ce
[list]: ../src/java/resources/files/jre/blocked.certs
