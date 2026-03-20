package frameworks

import (
	"encoding/json"
	"fmt"
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/resources"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// ProtectAppSecurityProviderFramework implements Safenet ProtectApp security provider support
// This framework provides integration with Safenet ProtectApp (now Gemalto/Thales) for key management
type ProtectAppSecurityProviderFramework struct {
	context *common.Context
}

// NewProtectAppSecurityProviderFramework creates a new ProtectApp security provider framework instance
func NewProtectAppSecurityProviderFramework(ctx *common.Context) *ProtectAppSecurityProviderFramework {
	return &ProtectAppSecurityProviderFramework{context: ctx}
}

// Detect checks if ProtectApp security provider should be included
// Detects when a service with "protectapp" in its name/label/tag is bound
func (p *ProtectAppSecurityProviderFramework) Detect() (string, error) {
	// Check for bound ProtectApp service in VCAP_SERVICES
	protectAppService, err := p.findProtectAppService()
	if err != nil {
		return "", nil // Service not found, don't enable
	}

	// Verify required credentials exist
	credentials, ok := protectAppService["credentials"].(map[string]interface{})
	if !ok {
		return "", nil
	}

	// Check for required fields: client and trusted_certificates
	if _, ok := credentials["client"]; !ok {
		return "", nil
	}
	if _, ok := credentials["trusted_certificates"]; !ok {
		return "", nil
	}

	// Get version from manifest
	dep, err := p.context.Manifest.DefaultVersion("protect-app-security-provider")
	if err != nil {
		return "", nil
	}

	return fmt.Sprintf("protect-app-security-provider=%s", dep.Version), nil
}

// Supply installs the ProtectApp security provider JAR
func (p *ProtectAppSecurityProviderFramework) Supply() error {
	p.context.Log.BeginStep("Installing ProtectApp Security Provider")

	// Get protect-app-security-provider dependency from manifest
	dep, err := p.context.Manifest.DefaultVersion("protect-app-security-provider")
	if err != nil {
		return fmt.Errorf("unable to determine ProtectApp Security Provider version: %w", err)
	}

	// Install ProtectApp security provider
	protectAppDir := filepath.Join(p.context.Stager.DepDir(), "protect_app_security_provider")
	if err := p.context.Installer.InstallDependency(dep, protectAppDir); err != nil {
		return fmt.Errorf("failed to install ProtectApp Security Provider: %w", err)
	}

	// Install default configuration from embedded resources
	if err := p.installDefaultConfiguration(protectAppDir); err != nil {
		p.context.Log.Warning("Could not install default ProtectApp configuration: %s", err.Error())
	}

	p.context.Log.Info("Installed ProtectApp Security Provider version %s", dep.Version)
	return nil
}

// installDefaultConfiguration installs the default IngrianNAE.properties from embedded resources
func (p *ProtectAppSecurityProviderFramework) installDefaultConfiguration(protectAppDir string) error {
	configPath := filepath.Join(protectAppDir, "IngrianNAE.properties")

	// Check if configuration already exists (user-provided or from external config)
	if _, err := os.Stat(configPath); err == nil {
		p.context.Log.Debug("IngrianNAE.properties already exists, skipping default configuration")
		return nil
	}

	// Read embedded IngrianNAE.properties
	embeddedPath := "protect_app_security_provider/IngrianNAE.properties"
	configData, err := resources.GetResource(embeddedPath)
	if err != nil {
		return fmt.Errorf("failed to read embedded IngrianNAE.properties: %w", err)
	}

	// Write configuration file (no template processing needed)
	if err := os.WriteFile(configPath, configData, 0644); err != nil {
		return fmt.Errorf("failed to write IngrianNAE.properties: %w", err)
	}

	p.context.Log.Info("Installed default ProtectApp configuration")
	p.context.Log.Debug("  - IngrianNAE.properties (connection and cache settings)")
	return nil
}

// Finalize configures the ProtectApp security provider for runtime
func (p *ProtectAppSecurityProviderFramework) Finalize() error {
	// Get ProtectApp service credentials
	protectAppService, err := p.findProtectAppService()
	if err != nil {
		return fmt.Errorf("ProtectApp service not found: %w", err)
	}

	credentials, ok := protectAppService["credentials"].(map[string]interface{})
	if !ok {
		return fmt.Errorf("ProtectApp service credentials not found")
	}

	protectAppDir := filepath.Join(p.context.Stager.DepDir(), "protect_app_security_provider")
	keystorePath := filepath.Join(protectAppDir, "nae-keystore.jks")
	keystorePassword := "nae-keystore-password"

	// Process client credentials (certificate and private key)
	if err := p.processClientCredentials(credentials, protectAppDir, keystorePath, keystorePassword); err != nil {
		return fmt.Errorf("failed to process client credentials: %w", err)
	}

	// Process trusted certificates
	if err := p.processTrustedCertificates(credentials, keystorePath, keystorePassword); err != nil {
		return fmt.Errorf("failed to process trusted certificates: %w", err)
	}

	// Get buildpack index for multi-buildpack support
	depsIdx := p.context.Stager.DepsIdx()

	// Get version for JAR name
	dep, err := p.context.Manifest.DefaultVersion("protect-app-security-provider")
	if err != nil {
		return fmt.Errorf("unable to determine ProtectApp Security Provider version: %w", err)
	}

	// Build runtime paths
	runtimeProtectAppDir := fmt.Sprintf("$DEPS_DIR/%s/protect_app_security_provider", depsIdx)
	runtimeKeystorePath := filepath.Join(runtimeProtectAppDir, "nae-keystore.jks")
	runtimeProtectAppJar := filepath.Join(runtimeProtectAppDir, "ext", fmt.Sprintf("IngrianNAE-%s.000.jar", dep.Version))

	// Build Java options for ProtectApp
	javaOptsSlice := []string{
		fmt.Sprintf("-Xbootclasspath/a:%s", runtimeProtectAppJar),
		fmt.Sprintf("-Dcom.ingrian.security.nae.IngrianNAE_Properties_Conf_Filename=%s/IngrianNAE.properties", runtimeProtectAppDir),
		fmt.Sprintf("-Dcom.ingrian.security.nae.Key_Store_Location=%s", runtimeKeystorePath),
		fmt.Sprintf("-Dcom.ingrian.security.nae.Key_Store_Password=%s", keystorePassword),
	}

	// Add additional properties from credentials (excluding client and trusted_certificates)
	for key, value := range credentials {
		if key != "client" && key != "trusted_certificates" {
			javaOptsSlice = append(javaOptsSlice, fmt.Sprintf("-Dcom.ingrian.security.nae.%s=%v", key, value))
		}
	}

	// Add security provider property
	javaOptsSlice = append(javaOptsSlice, fmt.Sprintf("-Djava.security.properties=%s/java.security", runtimeProtectAppDir))

	// Combine all options
	javaOptsStr := strings.Join(javaOptsSlice, " ")

	// Write to .opts file using priority 38
	if err := writeJavaOptsFile(p.context, 38, "protect_app_security_provider", javaOptsStr); err != nil {
		return fmt.Errorf("failed to write java_opts file: %w", err)
	}

	// Write java.security file with ProtectApp security provider
	securityProps := "security.provider.1=com.ingrian.security.nae.IngrianProvider\n"
	securityPropsPath := filepath.Join(protectAppDir, "java.security")
	if err := os.WriteFile(securityPropsPath, []byte(securityProps), 0644); err != nil {
		return fmt.Errorf("failed to write java.security file: %w", err)
	}

	p.context.Log.Info("Configured ProtectApp Security Provider")
	return nil
}

// processClientCredentials processes client certificate and private key, creates PKCS12 and imports to keystore
func (p *ProtectAppSecurityProviderFramework) processClientCredentials(credentials map[string]interface{}, protectAppDir, keystorePath, keystorePassword string) error {
	client, ok := credentials["client"].(map[string]interface{})
	if !ok {
		return fmt.Errorf("client credentials not found")
	}

	certificate, ok := client["certificate"].(string)
	if !ok || certificate == "" {
		return fmt.Errorf("client certificate not found")
	}

	privateKey, ok := client["private_key"].(string)
	if !ok || privateKey == "" {
		return fmt.Errorf("client private key not found")
	}

	// Write certificate to temp file
	certFile := filepath.Join(protectAppDir, "client-cert.pem")
	if err := os.WriteFile(certFile, []byte(certificate+"\n"), 0600); err != nil {
		return fmt.Errorf("failed to write client certificate: %w", err)
	}
	defer os.Remove(certFile)

	// Write private key to temp file
	keyFile := filepath.Join(protectAppDir, "client-key.pem")
	if err := os.WriteFile(keyFile, []byte(privateKey+"\n"), 0600); err != nil {
		return fmt.Errorf("failed to write client private key: %w", err)
	}
	defer os.Remove(keyFile)

	// Create PKCS12 file using openssl
	pkcs12File := filepath.Join(protectAppDir, "client.p12")
	cmd := exec.Command("openssl", "pkcs12", "-export",
		"-in", certFile,
		"-inkey", keyFile,
		"-name", "client",
		"-out", pkcs12File,
		"-passout", "pass:"+keystorePassword)

	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("failed to create PKCS12: %w, output: %s", err, string(output))
	}
	defer os.Remove(pkcs12File)

	// Get Java home for keytool
	javaHome := os.Getenv("JAVA_HOME")
	if javaHome == "" {
		javaHome = "/usr/lib/jvm/default-java" // Fallback
	}
	keytool := filepath.Join(javaHome, "bin", "keytool")

	// Import PKCS12 into Java keystore
	cmd = exec.Command(keytool, "-importkeystore", "-noprompt",
		"-destkeystore", keystorePath,
		"-deststorepass", keystorePassword,
		"-srckeystore", pkcs12File,
		"-srcstorepass", keystorePassword,
		"-srcstoretype", "pkcs12",
		"-alias", "client")

	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("failed to import client credentials to keystore: %w, output: %s", err, string(output))
	}

	return nil
}

// processTrustedCertificates imports trusted certificates into the keystore
func (p *ProtectAppSecurityProviderFramework) processTrustedCertificates(credentials map[string]interface{}, keystorePath, keystorePassword string) error {
	trustedCerts, ok := credentials["trusted_certificates"].([]interface{})
	if !ok {
		return fmt.Errorf("trusted_certificates not found")
	}

	// Get Java home for keytool
	javaHome := os.Getenv("JAVA_HOME")
	if javaHome == "" {
		javaHome = "/usr/lib/jvm/default-java" // Fallback
	}
	keytool := filepath.Join(javaHome, "bin", "keytool")

	protectAppDir := filepath.Join(p.context.Stager.DepDir(), "protect_app_security_provider")

	for i, cert := range trustedCerts {
		certStr, ok := cert.(string)
		if !ok {
			continue
		}

		// Write certificate to temp file
		certFile := filepath.Join(protectAppDir, fmt.Sprintf("trusted-cert-%d.pem", i))
		if err := os.WriteFile(certFile, []byte(certStr+"\n"), 0600); err != nil {
			return fmt.Errorf("failed to write trusted certificate %d: %w", i, err)
		}
		defer os.Remove(certFile)

		// Import certificate into keystore
		cmd := exec.Command(keytool, "-importcert", "-noprompt",
			"-keystore", keystorePath,
			"-storepass", keystorePassword,
			"-file", certFile,
			"-alias", fmt.Sprintf("trusted-%d", i))

		if output, err := cmd.CombinedOutput(); err != nil {
			return fmt.Errorf("failed to import trusted certificate %d: %w, output: %s", i, err, string(output))
		}
	}

	return nil
}

// findProtectAppService locates the ProtectApp service in VCAP_SERVICES
func (p *ProtectAppSecurityProviderFramework) findProtectAppService() (map[string]interface{}, error) {
	vcapServices := os.Getenv("VCAP_SERVICES")
	if vcapServices == "" {
		return nil, fmt.Errorf("VCAP_SERVICES not set")
	}

	var services map[string][]map[string]interface{}
	if err := json.Unmarshal([]byte(vcapServices), &services); err != nil {
		return nil, fmt.Errorf("failed to parse VCAP_SERVICES: %w", err)
	}

	for serviceType, serviceList := range services {
		if common.ContainsIgnoreCase(serviceType, "protectapp") {
			if len(serviceList) > 0 {
				return serviceList[0], nil
			}
		}

		for _, service := range serviceList {
			if name, ok := service["name"].(string); ok {
				if common.ContainsIgnoreCase(name, "protectapp") {
					return service, nil
				}
			}

			if label, ok := service["label"].(string); ok {
				if common.ContainsIgnoreCase(label, "protectapp") {
					return service, nil
				}
			}

			if tags, ok := service["tags"].([]interface{}); ok {
				for _, tag := range tags {
					if tagStr, ok := tag.(string); ok {
						if common.ContainsIgnoreCase(tagStr, "protectapp") {
							return service, nil
						}
					}
				}
			}
		}
	}

	return nil, fmt.Errorf("no ProtectApp service found")
}
