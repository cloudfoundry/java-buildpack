# Using Custom JREs

This guide explains how to use custom Java Runtime Environments (JREs) with the Cloud Foundry Java Buildpack when the JRE you need is not available in the buildpack's manifest.

## ⚠️ IMPORTANT: Migration from Ruby Buildpack

**If you are migrating from the Ruby-based Java Buildpack:**

The Go-based buildpack **DOES NOT SUPPORT** the `repository_root` configuration approach that was available in the Ruby buildpack. 

**Ruby Buildpack (NO LONGER WORKS):**
```bash
# ❌ This does NOT work in the Go buildpack
cf set-env myapp JBP_CONFIG_ORACLE_JRE '{ jre: { repository_root: "https://my-repo.com" } }'
```

**Go Buildpack (Required Approach):**
- You **MUST** fork the buildpack and add JRE entries to `manifest.yml`
- Runtime `repository_root` configuration via `JBP_CONFIG_*` environment variables is not supported
- This change improves security and build reproducibility by requiring explicit manifest entries

See Option 1 below for the correct approach.

---

## Overview

The Java Buildpack includes OpenJDK, Zulu, and SAPMachine JREs in its manifest. If you need a different JRE or a specific version not included, you have two options:

1. **Fork the buildpack and add custom manifest entries** (Recommended & Required for BYOL JREs)
2. **Use a multi-buildpack approach with a supply buildpack**

---

## Option 1: Fork Buildpack and Modify Manifest (Recommended)

This is the recommended approach as it follows CloudFoundry best practices and maintains security through SHA256 verification.

### When to Use This Approach

- You need Oracle JRE, GraalVM, IBM Semeru, or other BYOL (Bring Your Own License) JREs
- You need a specific version not in the manifest
- You want to use an internal mirror of JREs for air-gapped environments
- You need consistent, reproducible builds with specific JRE versions

### Step-by-Step Guide

#### 1. Fork the Java Buildpack

```bash
# Clone the Java Buildpack repository
git clone https://github.com/cloudfoundry/java-buildpack.git my-custom-java-buildpack
cd my-custom-java-buildpack

# Create a feature branch
git checkout -b add-custom-jre
```

#### 2. Add Your JRE to manifest.yml

Edit `manifest.yml` and add your JRE entry under the `dependencies` section:

```yaml
dependencies:
  # ... existing dependencies ...

  # Custom Oracle JRE
  - name: oracle
    version: 17.0.13
    uri: https://download.oracle.com/java/17/archive/jdk-17.0.13_linux-x64_bin.tar.gz
    sha256: 9d5cf622a8ca7a0b2f7c26b87b7a9a8ad6c2f00f23c6f2a6f2f6e4e3c5b8d9e1
    cf_stacks:
      - cflinuxfs4

  # Custom GraalVM CE
  - name: graalvm
    version: 21.0.5
    uri: https://github.com/graalvm/graalvm-ce-builds/releases/download/jdk-21.0.5/graalvm-community-jdk-21.0.5_linux-x64_bin.tar.gz
    sha256: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2
    cf_stacks:
      - cflinuxfs4

  # IBM Semeru Runtime (formerly IBM JRE)
  - name: ibm
    version: 17.0.13.0
    uri: https://github.com/ibmruntimes/semeru17-binaries/releases/download/jdk-17.0.13+11_openj9-0.48.0/ibm-semeru-open-jre_x64_linux_17.0.13_11_openj9-0.48.0.tar.gz
    sha256: f1e2d3c4b5a6978869706a5b4c3d2e1f0a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5
    cf_stacks:
      - cflinuxfs4
```

**Important Fields:**

- `name`: The JRE identifier (must match what the buildpack expects: `oracle`, `graalvm`, `ibm`, `zing`)
- `version`: The exact version string
- `uri`: Direct download URL to the JRE tarball
- `sha256`: SHA-256 checksum of the tarball (for security verification)
- `cf_stacks`: CloudFoundry stack compatibility (typically `cflinuxfs4`)

#### 3. Calculate SHA256 Checksum

You must provide the correct SHA256 checksum for security verification:

```bash
# Download the JRE tarball
curl -LO https://example.com/jre-download.tar.gz

# Calculate SHA256
sha256sum jre-download.tar.gz
# Output: a1b2c3d4... jre-download.tar.gz

# Use this hash in manifest.yml
```

#### 4. Add URL Mapping (Optional)

If your JRE uses a non-standard naming convention, add a URL mapping:

```yaml
url_to_dependency_map:
  # ... existing mappings ...

  - match: oracle-jre-(\d+\.\d+\.\d+)
    name: oracle
    version: $1

  - match: graalvm-jre-(\d+\.\d+\.\d+)
    name: graalvm
    version: $1
```

#### 5. Add Default Version (Optional)

Set a default version for your custom JRE:

```yaml
default_versions:
  # ... existing defaults ...

  - name: oracle
    version: 17.x

  - name: graalvm
    version: 21.x
```

#### 6. Build and Package Your Custom Buildpack

```bash
# Build the buildpack binaries
./scripts/build.sh

# Package the buildpack
./scripts/package.sh

# This creates: build/buildpack.zip
```

#### 7. Upload to Cloud Foundry

```bash
# Upload as a custom buildpack
cf create-buildpack my-custom-java-buildpack build/buildpack.zip 1

# Or update an existing custom buildpack
cf update-buildpack my-custom-java-buildpack -p build/buildpack.zip
```

#### 8. Use Your Custom Buildpack

**Option A: Specify buildpack in manifest.yml**

```yaml
# manifest.yml
applications:
  - name: my-app
    buildpacks:
      - my-custom-java-buildpack
    env:
      BP_JAVA_VERSION: 17
      JBP_CONFIG_COMPONENTS: '{"jres": ["OracleJRE"]}'
```

**Option B: Specify buildpack on command line**

```bash
# Push with custom buildpack
cf push my-app -b my-custom-java-buildpack

# Set JRE version
cf set-env my-app BP_JAVA_VERSION 17

# Select JRE vendor (if multiple JREs available)
cf set-env my-app JBP_CONFIG_COMPONENTS '{"jres": ["GraalVMJRE"]}'

# Restage to apply changes
cf restage my-app
```

### Complete Example: Adding Oracle JRE

```yaml
# manifest.yml additions

url_to_dependency_map:
  - match: jdk-(\d+\.\d+\.\d+)_linux-x64_bin\.tar\.gz
    name: oracle
    version: $1

default_versions:
  - name: oracle
    version: 17.x

dependencies:
  # Oracle JRE 17
  - name: oracle
    version: 17.0.13
    uri: https://download.oracle.com/java/17/archive/jdk-17.0.13_linux-x64_bin.tar.gz
    sha256: 9d5cf622a8ca7a0b2f7c26b87b7a9a8ad6c2f00f23c6f2a6f2f6e4e3c5b8d9e1
    cf_stacks:
      - cflinuxfs4

  # Oracle JRE 21
  - name: oracle
    version: 21.0.5
    uri: https://download.oracle.com/java/21/archive/jdk-21.0.5_linux-x64_bin.tar.gz
    sha256: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2
    cf_stacks:
      - cflinuxfs4
```

**Application usage:**

```bash
# Push application with Oracle JRE 17
cf push my-app -b my-custom-java-buildpack
cf set-env my-app BP_JAVA_VERSION 17
cf set-env my-app JBP_CONFIG_COMPONENTS '{"jres": ["OracleJRE"]}'
cf restage my-app
```

### Maintenance

**Updating JRE Versions:**

1. Download the new JRE tarball
2. Calculate its SHA256 checksum
3. Add new entry to `manifest.yml`
4. Rebuild and repackage buildpack
5. Update buildpack in Cloud Foundry

**Example update workflow:**

```bash
# Download new version
curl -LO https://example.com/jre-17.0.14.tar.gz

# Calculate checksum
sha256sum jre-17.0.14.tar.gz

# Edit manifest.yml with new version and checksum
# Rebuild
./scripts/build.sh && ./scripts/package.sh

# Update buildpack
cf update-buildpack my-custom-java-buildpack -p build/buildpack.zip
```

---

## Option 2: Multi-Buildpack with Supply Buildpack

This approach uses Cloud Foundry's multi-buildpack feature to install a custom JRE before the Java Buildpack runs.

### When to Use This Approach

- You want to install JREs dynamically without forking the buildpack
- You need different JREs for different applications without maintaining separate buildpacks
- You want to test JREs before committing them to a manifest
- Your JRE installation logic is complex (e.g., requires authentication, multiple steps)

### How Multi-Buildpack Works

Cloud Foundry allows you to use multiple buildpacks in sequence:

1. **Supply buildpack(s)** - Install dependencies and set up environment
2. **Final buildpack** - Detect application type and create start command

In this approach:
- A custom supply buildpack installs your JRE
- The Java Buildpack detects the pre-installed JRE and uses it

### Step-by-Step Guide

#### 1. Create a Supply Buildpack

Create a new directory for your supply buildpack:

```bash
mkdir jre-supply-buildpack
cd jre-supply-buildpack
```

#### 2. Create bin/supply Script

Create `bin/supply` (the main script that installs the JRE):

```bash
#!/bin/bash
set -euo pipefail

# Supply buildpack arguments
BUILD_DIR=$1
CACHE_DIR=$2
DEPS_DIR=$3
DEPS_IDX=$4

echo "-----> Installing Custom JRE"

# JRE Configuration (can be overridden by environment variables)
JRE_VERSION="${JRE_VERSION:-17.0.13}"
JRE_URL="${JRE_URL:-https://download.oracle.com/java/17/archive/jdk-${JRE_VERSION}_linux-x64_bin.tar.gz}"
JRE_SHA256="${JRE_SHA256:-9d5cf622a8ca7a0b2f7c26b87b7a9a8ad6c2f00f23c6f2a6f2f6e4e3c5b8d9e1}"

# Installation paths
JRE_DIR="${DEPS_DIR}/${DEPS_IDX}/jre"
CACHE_FILE="${CACHE_DIR}/jre-${JRE_VERSION}.tar.gz"

# Download JRE (with caching)
if [ ! -f "${CACHE_FILE}" ]; then
  echo "       Downloading JRE ${JRE_VERSION}"
  curl -fsSL -o "${CACHE_FILE}" "${JRE_URL}"
  
  # Verify checksum
  echo "${JRE_SHA256}  ${CACHE_FILE}" | sha256sum -c - || {
    echo "ERROR: SHA256 checksum verification failed"
    rm -f "${CACHE_FILE}"
    exit 1
  }
else
  echo "       Using cached JRE ${JRE_VERSION}"
fi

# Extract JRE
echo "       Extracting JRE to ${JRE_DIR}"
mkdir -p "${JRE_DIR}"
tar xzf "${CACHE_FILE}" -C "${JRE_DIR}" --strip-components=1

# Find JAVA_HOME (handle nested directories)
JAVA_HOME=$(find "${JRE_DIR}" -maxdepth 2 -name java -type f -executable | head -1)
JAVA_HOME=$(dirname "$(dirname "${JAVA_HOME}")")

if [ -z "${JAVA_HOME}" ]; then
  echo "ERROR: Could not find java executable in JRE"
  exit 1
fi

echo "       JAVA_HOME: ${JAVA_HOME}"

# Create profile.d script to set JAVA_HOME at runtime
PROFILE_D="${DEPS_DIR}/${DEPS_IDX}/profile.d"
mkdir -p "${PROFILE_D}"

cat > "${PROFILE_D}/java.sh" <<EOF
export JAVA_HOME="${JAVA_HOME}"
export PATH="\${JAVA_HOME}/bin:\${PATH}"
EOF

chmod +x "${PROFILE_D}/java.sh"

# Verify installation
"${JAVA_HOME}/bin/java" -version

echo "-----> Custom JRE installation complete"
```

Make it executable:

```bash
chmod +x bin/supply
```

#### 3. Create bin/finalize Script (Optional)

Create `bin/finalize` (runs after all supply buildpacks):

```bash
#!/bin/bash
set -euo pipefail

# Finalize buildpack arguments
BUILD_DIR=$1
CACHE_DIR=$2
DEPS_DIR=$3
DEPS_IDX=$4

# Nothing to do in finalize for JRE supply
exit 0
```

Make it executable:

```bash
chmod +x bin/finalize
```

#### 4. Create manifest.yml

```yaml
---
language: java-jre-supply
```

#### 5. Package the Supply Buildpack

```bash
# Create a zip file
zip -r jre-supply-buildpack.zip bin/ manifest.yml
```

#### 6. Upload Supply Buildpack to Cloud Foundry

```bash
# Upload the supply buildpack
cf create-buildpack jre-supply-buildpack jre-supply-buildpack.zip 1 --enable
```

#### 7. Use Multi-Buildpack in Your Application

**Option A: In manifest.yml**

```yaml
# manifest.yml
applications:
  - name: my-app
    buildpacks:
      - jre-supply-buildpack  # Supply buildpack (installs JRE)
      - java_buildpack        # Final buildpack (detects app type)
    env:
      JRE_VERSION: "17.0.13"
      JRE_URL: "https://download.oracle.com/java/17/archive/jdk-17.0.13_linux-x64_bin.tar.gz"
      JRE_SHA256: "9d5cf622a8ca7a0b2f7c26b87b7a9a8ad6c2f00f23c6f2a6f2f6e4e3c5b8d9e1"
```

**Option B: Command Line**

```bash
# Set buildpack order
cf v3-push my-app -b jre-supply-buildpack -b java_buildpack

# Or using manifest
cf push my-app
```

### Advanced Supply Buildpack Examples

#### Example 1: Download from Authenticated Source

```bash
#!/bin/bash
set -euo pipefail

BUILD_DIR=$1
CACHE_DIR=$2
DEPS_DIR=$3
DEPS_IDX=$4

echo "-----> Installing JRE from authenticated source"

# Require authentication credentials
if [ -z "${JRE_USERNAME:-}" ] || [ -z "${JRE_PASSWORD:-}" ]; then
  echo "ERROR: JRE_USERNAME and JRE_PASSWORD must be set"
  exit 1
fi

JRE_URL="${JRE_URL}"
JRE_DIR="${DEPS_DIR}/${DEPS_IDX}/jre"
CACHE_FILE="${CACHE_DIR}/jre.tar.gz"

# Download with authentication
echo "       Downloading JRE (authenticated)"
curl -fsSL -u "${JRE_USERNAME}:${JRE_PASSWORD}" -o "${CACHE_FILE}" "${JRE_URL}"

# Extract and set up JAVA_HOME
mkdir -p "${JRE_DIR}"
tar xzf "${CACHE_FILE}" -C "${JRE_DIR}" --strip-components=1

JAVA_HOME="${JRE_DIR}"
PROFILE_D="${DEPS_DIR}/${DEPS_IDX}/profile.d"
mkdir -p "${PROFILE_D}"

cat > "${PROFILE_D}/java.sh" <<EOF
export JAVA_HOME="${JAVA_HOME}"
export PATH="\${JAVA_HOME}/bin:\${PATH}"
EOF

chmod +x "${PROFILE_D}/java.sh"
echo "-----> JRE installation complete"
```

**Usage:**

```bash
cf set-env my-app JRE_USERNAME "my-username"
cf set-env my-app JRE_PASSWORD "my-password"
cf set-env my-app JRE_URL "https://secure-repo.example.com/jre.tar.gz"
cf restage my-app
```

#### Example 2: Install from Internal Artifactory

```bash
#!/bin/bash
set -euo pipefail

BUILD_DIR=$1
CACHE_DIR=$2
DEPS_DIR=$3
DEPS_IDX=$4

echo "-----> Installing JRE from Artifactory"

# Configuration
ARTIFACTORY_URL="${ARTIFACTORY_URL:-https://artifactory.company.com}"
ARTIFACTORY_REPO="${ARTIFACTORY_REPO:-jre-releases}"
JRE_VERSION="${JRE_VERSION:-17.0.13}"
JRE_ARTIFACT="openjdk-${JRE_VERSION}-linux-x64.tar.gz"

# API token for Artifactory
ARTIFACTORY_TOKEN="${ARTIFACTORY_TOKEN}"

# Construct download URL
DOWNLOAD_URL="${ARTIFACTORY_URL}/artifactory/${ARTIFACTORY_REPO}/${JRE_ARTIFACT}"

JRE_DIR="${DEPS_DIR}/${DEPS_IDX}/jre"
CACHE_FILE="${CACHE_DIR}/${JRE_ARTIFACT}"

# Download from Artifactory
if [ ! -f "${CACHE_FILE}" ]; then
  echo "       Downloading ${JRE_ARTIFACT} from Artifactory"
  curl -fsSL -H "X-JFrog-Art-Api: ${ARTIFACTORY_TOKEN}" \
    -o "${CACHE_FILE}" \
    "${DOWNLOAD_URL}"
else
  echo "       Using cached ${JRE_ARTIFACT}"
fi

# Extract
mkdir -p "${JRE_DIR}"
tar xzf "${CACHE_FILE}" -C "${JRE_DIR}" --strip-components=1

# Set up environment
JAVA_HOME="${JRE_DIR}"
PROFILE_D="${DEPS_DIR}/${DEPS_IDX}/profile.d"
mkdir -p "${PROFILE_D}"

cat > "${PROFILE_D}/java.sh" <<EOF
export JAVA_HOME="${JAVA_HOME}"
export PATH="\${JAVA_HOME}/bin:\${PATH}"
EOF

chmod +x "${PROFILE_D}/java.sh"
echo "-----> JRE from Artifactory installed"
```

**Usage:**

```bash
cf set-env my-app ARTIFACTORY_URL "https://artifactory.company.com"
cf set-env my-app ARTIFACTORY_REPO "jre-releases"
cf set-env my-app ARTIFACTORY_TOKEN "your-api-token"
cf set-env my-app JRE_VERSION "17.0.13"
cf restage my-app
```

### Testing Your Supply Buildpack

```bash
# Test locally with pack CLI
pack build my-app \
  --buildpack jre-supply-buildpack.zip \
  --buildpack cloudfoundry/java-buildpack \
  --path /path/to/app

# Or test in Cloud Foundry
cf push my-app -b jre-supply-buildpack -b java_buildpack
```

### Troubleshooting

**Issue: Java Buildpack doesn't detect the pre-installed JRE**

Solution: Ensure your supply buildpack sets `JAVA_HOME` correctly in the profile.d script.

**Issue: SHA256 verification fails**

Solution: Recalculate the SHA256 checksum:
```bash
sha256sum jre-download.tar.gz
```

**Issue: JRE not found at runtime**

Solution: Check that the profile.d script is created and executable:
```bash
cf ssh my-app
cat /home/vcap/deps/0/profile.d/java.sh
```

---

## Comparison: Option 1 vs Option 2

| Aspect | Option 1: Fork Buildpack | Option 2: Supply Buildpack |
|--------|--------------------------|----------------------------|
| **Complexity** | Moderate | Low to Moderate |
| **Maintenance** | Requires rebuilding buildpack | Update environment variables only |
| **Security** | SHA256 verification enforced | Manual implementation needed |
| **Flexibility** | All apps use same JRE versions | Different JREs per app |
| **Offline Support** | Yes (if dependencies cached) | Depends on implementation |
| **Auditability** | High (manifest is source of truth) | Medium (env vars can change) |
| **Best For** | Production environments | Development/testing, dynamic needs |

---

## Additional Resources

- [Cloud Foundry Java Buildpack Documentation](https://github.com/cloudfoundry/java-buildpack)
- [Cloud Foundry Multi-Buildpack Guide](https://docs.cloudfoundry.org/buildpacks/use-multiple-buildpacks.html)
- [Writing Supply Buildpacks](https://docs.cloudfoundry.org/buildpacks/understand-buildpacks.html)
- [Buildpack Manifest Format](https://docs.cloudfoundry.org/buildpacks/understand-buildpacks.html#buildpack-manifest)

---

## Support

For issues or questions:
- File an issue on GitHub: https://github.com/cloudfoundry/java-buildpack/issues
- Cloud Foundry Slack: #buildpacks channel
