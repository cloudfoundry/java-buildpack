package frameworks

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// LunaSecurityProviderFramework implements Safenet Luna HSM Java Security Provider support
// This framework enables zero-touch integration with Gemalto Luna HSM for cryptographic operations
type LunaSecurityProviderFramework struct {
	context *Context
}

// NewLunaSecurityProviderFramework creates a new Luna security provider framework instance
func NewLunaSecurityProviderFramework(ctx *Context) *LunaSecurityProviderFramework {
	return &LunaSecurityProviderFramework{context: ctx}
}

// Detect checks if Luna security provider should be included
// Requires Luna service binding with client credentials
func (l *LunaSecurityProviderFramework) Detect() (string, error) {
	// Get VCAP_SERVICES to check for Luna service binding
	vcapServices, err := GetVCAPServices()
	if err != nil {
		return "", nil
	}

	// Check for Luna service binding (filter: /luna/)
	// Required fields: client, servers
	// Optional: groups (for HA configuration)
	if vcapServices.HasService("luna") ||
		vcapServices.HasServiceByNamePattern("luna") {
		return "Luna Security Provider", nil
	}

	return "", nil
}

// Supply installs the Luna security provider tarball and credentials
func (l *LunaSecurityProviderFramework) Supply() error {
	l.context.Log.BeginStep("Installing Luna Security Provider")

	// Get luna-security-provider dependency from manifest
	dep, err := l.context.Manifest.DefaultVersion("luna-security-provider")
	if err != nil {
		return fmt.Errorf("unable to determine Luna Security Provider version: %w", err)
	}

	// Install Luna security provider tarball (JARs + native libraries)
	lunaDir := filepath.Join(l.context.Stager.DepDir(), "luna_security_provider")
	if err := l.context.Installer.InstallDependency(dep, lunaDir); err != nil {
		return fmt.Errorf("failed to install Luna Security Provider: %w", err)
	}

	// Create ext directory for Java 8 compatibility
	extDir := filepath.Join(lunaDir, "ext")
	if err := os.MkdirAll(extDir, 0755); err != nil {
		return fmt.Errorf("failed to create ext directory: %w", err)
	}

	// Create symlinks in ext directory
	lunaProviderJar := filepath.Join(lunaDir, "jsp", "LunaProvider.jar")
	lunaAPIso := filepath.Join(lunaDir, "jsp", "64", "libLunaAPI.so")

	if err := l.createSymlink(lunaProviderJar, filepath.Join(extDir, "LunaProvider.jar")); err != nil {
		l.context.Log.Warning("Failed to create LunaProvider.jar symlink: %s", err.Error())
	}
	if err := l.createSymlink(lunaAPIso, filepath.Join(extDir, "libLunaAPI.so")); err != nil {
		l.context.Log.Warning("Failed to create libLunaAPI.so symlink: %s", err.Error())
	}

	// Write credentials from VCAP_SERVICES
	if err := l.writeCredentials(); err != nil {
		return fmt.Errorf("failed to write Luna credentials: %w", err)
	}

	l.context.Log.Info("Installed Luna Security Provider version %s", dep.Version)
	return nil
}

// Finalize configures the Luna security provider for runtime
func (l *LunaSecurityProviderFramework) Finalize() error {
	// Set ChrystokiConfigurationPath environment variable with runtime path
	if err := l.context.Stager.WriteEnvFile("ChrystokiConfigurationPath", "$DEPS_DIR/0/luna_security_provider"); err != nil {
		return fmt.Errorf("failed to set ChrystokiConfigurationPath: %w", err)
	}

	// Detect Java version to determine extension mechanism
	javaVersion, err := l.getJavaMajorVersion()
	if err != nil {
		l.context.Log.Warning("Unable to detect Java version, assuming Java 8: %s", err.Error())
		javaVersion = 8
	}

	var javaOpts string
	if javaVersion >= 9 {
		// Java 9+: Add to bootstrap classpath and set LD_LIBRARY_PATH
		lunaProviderJar := "$DEPS_DIR/0/luna_security_provider/jsp/LunaProvider.jar"
		ldLibPath := "$DEPS_DIR/0/luna_security_provider/jsp/64"

		// Build JAVA_OPTS with runtime path
		javaOpts = fmt.Sprintf("-Xbootclasspath/a:%s", lunaProviderJar)

		// Set LD_LIBRARY_PATH for native library loading
		existingLdPath := os.Getenv("LD_LIBRARY_PATH")
		newLdPath := ldLibPath
		if existingLdPath != "" {
			newLdPath = existingLdPath + ":" + ldLibPath
		}

		if err := l.context.Stager.WriteEnvFile("LD_LIBRARY_PATH", newLdPath); err != nil {
			return fmt.Errorf("failed to set LD_LIBRARY_PATH for Luna Security Provider: %w", err)
		}
	} else {
		// Java 8: Use extension directory
		extDir := "$DEPS_DIR/0/luna_security_provider/ext"
		javaOpts = fmt.Sprintf("-Djava.ext.dirs=%s:$JAVA_HOME/jre/lib/ext:$JAVA_HOME/lib/ext", extDir)
	}

	// Write to .opts file using priority 32
	if err := writeJavaOptsFile(l.context, 32, "luna_security_provider", javaOpts); err != nil {
		return fmt.Errorf("failed to write java_opts file: %w", err)
	}

	l.context.Log.Info("Luna Security Provider configured (priority 32)")
	return nil
}

// writeCredentials writes Luna credentials from VCAP_SERVICES to files
func (l *LunaSecurityProviderFramework) writeCredentials() error {
	// Get Luna service binding
	vcapServices, err := GetVCAPServices()
	if err != nil {
		return fmt.Errorf("unable to parse VCAP_SERVICES: %w", err)
	}

	// Find Luna service (try multiple lookup patterns)
	// VCAPServices is a map[string][]VCAPService where keys are service labels
	var credentials map[string]interface{}

	// Iterate over all service labels and services
	for label, services := range vcapServices {
		for _, service := range services {
			// Check if service name or label contains "luna"
			if strings.Contains(strings.ToLower(service.Name), "luna") ||
				strings.Contains(strings.ToLower(label), "luna") {
				credentials = service.Credentials
				break
			}
		}
		if credentials != nil {
			break
		}
	}

	if credentials == nil {
		return fmt.Errorf("Luna service binding not found in VCAP_SERVICES")
	}

	// Write client credentials (certificate and private key)
	if client, ok := credentials["client"].(map[string]interface{}); ok {
		if err := l.writeClientCredentials(client); err != nil {
			return fmt.Errorf("failed to write client credentials: %w", err)
		}
	}

	// Write server certificates
	if servers, ok := credentials["servers"].([]interface{}); ok {
		if err := l.writeServerCertificates(servers); err != nil {
			return fmt.Errorf("failed to write server certificates: %w", err)
		}

		// Write full Chrystoki.conf if groups are also present (HA configuration)
		if groups, ok := credentials["groups"].([]interface{}); ok {
			if err := l.writeConfiguration(servers, groups); err != nil {
				return fmt.Errorf("failed to write Chrystoki.conf: %w", err)
			}
		}
	}

	return nil
}

// writeClientCredentials writes client certificate and private key
func (l *LunaSecurityProviderFramework) writeClientCredentials(client map[string]interface{}) error {
	lunaDir := filepath.Join(l.context.Stager.DepDir(), "luna_security_provider")

	// Write client certificate
	if cert, ok := client["certificate"].(string); ok {
		certPath := filepath.Join(lunaDir, "client-certificate.pem")
		if err := os.WriteFile(certPath, []byte(cert+"\n"), 0644); err != nil {
			return fmt.Errorf("failed to write client certificate: %w", err)
		}
	}

	// Write client private key
	if key, ok := client["private-key"].(string); ok {
		keyPath := filepath.Join(lunaDir, "client-private-key.pem")
		if err := os.WriteFile(keyPath, []byte(key+"\n"), 0600); err != nil {
			return fmt.Errorf("failed to write client private key: %w", err)
		}
	}

	return nil
}

// writeServerCertificates writes server CA certificates
func (l *LunaSecurityProviderFramework) writeServerCertificates(servers []interface{}) error {
	lunaDir := filepath.Join(l.context.Stager.DepDir(), "luna_security_provider")
	certPath := filepath.Join(lunaDir, "server-certificates.pem")

	var content strings.Builder
	for _, server := range servers {
		if serverMap, ok := server.(map[string]interface{}); ok {
			if cert, ok := serverMap["certificate"].(string); ok {
				content.WriteString(cert)
				content.WriteString("\n")
			}
		}
	}

	if err := os.WriteFile(certPath, []byte(content.String()), 0644); err != nil {
		return fmt.Errorf("failed to write server certificates: %w", err)
	}

	return nil
}

// writeConfiguration writes full Chrystoki.conf with HA configuration
func (l *LunaSecurityProviderFramework) writeConfiguration(servers []interface{}, groups []interface{}) error {
	lunaDir := filepath.Join(l.context.Stager.DepDir(), "luna_security_provider")
	chrystokiPath := filepath.Join(lunaDir, "Chrystoki.conf")

	// Open file for appending (preserves default config)
	file, err := os.OpenFile(chrystokiPath, os.O_APPEND|os.O_WRONLY|os.O_CREATE, 0644)
	if err != nil {
		return fmt.Errorf("failed to open Chrystoki.conf: %w", err)
	}
	defer file.Close()

	// Write prologue (library configuration and client settings)
	if err := l.writePrologue(file); err != nil {
		return err
	}

	// Write server configurations
	for i, server := range servers {
		if serverMap, ok := server.(map[string]interface{}); ok {
			l.writeServer(file, i, serverMap)
		}
	}

	// Close LunaSA Client section
	file.WriteString("}\n\n")

	// Write VirtualToken section (HA groups)
	file.WriteString("VirtualToken = {\n")
	for i, group := range groups {
		if groupMap, ok := group.(map[string]interface{}); ok {
			l.writeGroup(file, i, groupMap)
		}
	}

	// Write epilogue (HA configuration)
	if err := l.writeEpilogue(file, groups); err != nil {
		return err
	}

	return nil
}

// writePrologue writes library configuration and client settings
func (l *LunaSecurityProviderFramework) writePrologue(file *os.File) error {
	lunaDir := filepath.Join(l.context.Stager.DepDir(), "luna_security_provider")

	// Get configuration values
	loggingEnabled := l.getConfigBool("logging_enabled", false)
	tcpKeepAlive := 0
	if l.getConfigBool("tcp_keep_alive_enabled", false) {
		tcpKeepAlive = 1
	}

	// Write Chrystoki2 library configuration
	file.WriteString("\nChrystoki2 = {\n")

	if loggingEnabled {
		libCklog := filepath.Join(lunaDir, "libs", "64", "libcklog2.so")
		libCryptoki := filepath.Join(lunaDir, "libs", "64", "libCryptoki2.so")

		file.WriteString(fmt.Sprintf("  LibUNIX64 = %s;\n", libCklog))
		file.WriteString("}\n\n")
		file.WriteString("CkLog2 = {\n")
		file.WriteString("  Enabled      = 1;\n")
		file.WriteString(fmt.Sprintf("  LibUNIX64    = %s;\n", libCryptoki))
		file.WriteString("  LoggingMask  = ALL_FUNC;\n")
		file.WriteString("  LogToStreams = 1;\n")
		file.WriteString("  NewFormat    = 1;\n")
		file.WriteString("}\n")
	} else {
		libCryptoki := filepath.Join(lunaDir, "libs", "64", "libCryptoki2.so")
		file.WriteString(fmt.Sprintf("  LibUNIX64 = %s;\n", libCryptoki))
		file.WriteString("}\n")
	}

	// Write LunaSA Client configuration
	clientCert := filepath.Join(lunaDir, "client-certificate.pem")
	clientKey := filepath.Join(lunaDir, "client-private-key.pem")
	htlDir := filepath.Join(lunaDir, "htl")
	serverCerts := filepath.Join(lunaDir, "server-certificates.pem")

	// Create htl directory
	os.MkdirAll(htlDir, 0755)

	file.WriteString("\nLunaSA Client = {\n")
	file.WriteString(fmt.Sprintf("  TCPKeepAlive = %d;\n", tcpKeepAlive))
	file.WriteString("  NetClient    = 1;\n\n")
	file.WriteString(fmt.Sprintf("  ClientCertFile    = %s;\n", clientCert))
	file.WriteString(fmt.Sprintf("  ClientPrivKeyFile = %s;\n", clientKey))
	file.WriteString(fmt.Sprintf("  HtlDir            = %s;\n", htlDir))
	file.WriteString(fmt.Sprintf("  ServerCAFile      = %s;\n\n", serverCerts))

	return nil
}

// writeServer writes a single server configuration
func (l *LunaSecurityProviderFramework) writeServer(file *os.File, index int, server map[string]interface{}) {
	paddedIndex := l.paddedIndex(index)

	if name, ok := server["name"].(string); ok {
		file.WriteString(fmt.Sprintf("  ServerName%s = %s;\n", paddedIndex, name))
		file.WriteString(fmt.Sprintf("  ServerPort%s = 1792;\n", paddedIndex))
		file.WriteString(fmt.Sprintf("  ServerHtl%s  = 0;\n\n", paddedIndex))
	}
}

// writeGroup writes a virtual token (HA group) configuration
func (l *LunaSecurityProviderFramework) writeGroup(file *os.File, index int, group map[string]interface{}) {
	paddedIndex := l.paddedIndex(index)

	label, _ := group["label"].(string)
	members, _ := group["members"].([]interface{})

	if label != "" && len(members) > 0 {
		file.WriteString(fmt.Sprintf("  VirtualToken%sLabel   = %s;\n", paddedIndex, label))

		// Serial number is 1 + first member
		if firstMember, ok := members[0].(string); ok {
			file.WriteString(fmt.Sprintf("  VirtualToken%sSN      = 1%s;\n", paddedIndex, firstMember))
		}

		// Members list
		var memberStrings []string
		for _, member := range members {
			if memberStr, ok := member.(string); ok {
				memberStrings = append(memberStrings, memberStr)
			}
		}
		file.WriteString(fmt.Sprintf("  VirtualToken%sMembers = %s;\n\n", paddedIndex, strings.Join(memberStrings, ",")))
	}
}

// writeEpilogue writes HA configuration and HASynchronize sections
func (l *LunaSecurityProviderFramework) writeEpilogue(file *os.File, groups []interface{}) error {
	haLoggingEnabled := l.getConfigBool("ha_logging_enabled", true)

	file.WriteString("}\n\n")
	file.WriteString("HAConfiguration = {\n")
	file.WriteString("  AutoReconnectInterval = 60;\n")
	file.WriteString("  HAOnly                = 1;\n")
	file.WriteString("  reconnAtt             = -1;\n")

	if haLoggingEnabled {
		file.WriteString("  haLogStatus           = enabled;\n")
		file.WriteString("  haLogToStdout         = enabled;\n")
	}

	file.WriteString("}\n\n")
	file.WriteString("HASynchronize = {\n")

	// Add each group label to HASynchronize
	for _, group := range groups {
		if groupMap, ok := group.(map[string]interface{}); ok {
			if label, ok := groupMap["label"].(string); ok {
				file.WriteString(fmt.Sprintf("  %s = 1;\n", label))
			}
		}
	}

	file.WriteString("}\n")

	return nil
}

// Helper functions

// createSymlink creates a symbolic link, removing existing link if present
func (l *LunaSecurityProviderFramework) createSymlink(target, link string) error {
	// Remove existing link if present
	os.Remove(link)

	// Create relative symlink
	relTarget, err := filepath.Rel(filepath.Dir(link), target)
	if err != nil {
		relTarget = target
	}

	return os.Symlink(relTarget, link)
}

// getJavaMajorVersion detects the Java major version from JAVA_HOME
func (l *LunaSecurityProviderFramework) getJavaMajorVersion() (int, error) {
	javaHome := os.Getenv("JAVA_HOME")
	if javaHome == "" {
		return 0, fmt.Errorf("JAVA_HOME not set")
	}

	releaseFile := filepath.Join(javaHome, "release")
	content, err := os.ReadFile(releaseFile)
	if err != nil {
		return 0, fmt.Errorf("failed to read release file: %w", err)
	}

	version := parseJavaVersion(string(content))
	if version == 0 {
		return 0, fmt.Errorf("unable to parse Java version")
	}

	return version, nil
}

// getConfigBool retrieves a boolean configuration value from JBP_CONFIG_LUNA_SECURITY_PROVIDER
func (l *LunaSecurityProviderFramework) getConfigBool(key string, defaultValue bool) bool {
	config := os.Getenv("JBP_CONFIG_LUNA_SECURITY_PROVIDER")
	if config == "" {
		return defaultValue
	}

	// Parse configuration for key
	if contains(config, key) {
		if contains(config, "true") {
			return true
		}
		if contains(config, "false") {
			return false
		}
	}

	return defaultValue
}

// paddedIndex returns a zero-padded two-digit index string
func (l *LunaSecurityProviderFramework) paddedIndex(index int) string {
	return fmt.Sprintf("%02d", index)
}
