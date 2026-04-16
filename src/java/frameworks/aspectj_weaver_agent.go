package frameworks

import (
	"fmt"
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"os"
	"path/filepath"
	"strings"
)

// AspectJWeaverAgentFramework represents the AspectJ Weaver Agent framework
type AspectJWeaverAgentFramework struct {
	context      *common.Context
	aspectjJar   string
	hasAopConfig bool
}

// NewAspectJWeaverAgentFramework creates a new AspectJ Weaver Agent framework instance
func NewAspectJWeaverAgentFramework(ctx *common.Context) *AspectJWeaverAgentFramework {
	return &AspectJWeaverAgentFramework{context: ctx}
}

// Detect determines if AspectJ Weaver JAR and configuration exist in the application
func (a *AspectJWeaverAgentFramework) Detect() (string, error) {
	config, err := a.loadConfig()
	if err != nil {
		a.context.Log.Warning("Failed to load aspectj weaver agent config: %s", err.Error())
		return "", nil // Don't fail the build
	}

	if !config.isEnabled() {
		return "", nil
	}
	// Look for aspectjweaver-*.jar in the application
	aspectjJar, err := a.findAspectJWeaver()
	if err != nil || aspectjJar == "" {
		return "", nil
	}

	// Check for aop.xml configuration in META-INF/aop.xml
	aopConfig := filepath.Join(a.context.Stager.BuildDir(), "META-INF", "aop.xml")
	if _, err := os.Stat(aopConfig); err == nil {
		a.aspectjJar = aspectjJar
		a.hasAopConfig = true
		a.context.Log.Info("AspectJ Weaver detected: %s with aop.xml", aspectjJar)
		return "aspectj-weaver", nil
	}

	// Also check in WEB-INF/classes/META-INF/aop.xml for web apps
	webInfAopConfig := filepath.Join(a.context.Stager.BuildDir(), "WEB-INF", "classes", "META-INF", "aop.xml")
	if _, err := os.Stat(webInfAopConfig); err == nil {
		a.aspectjJar = aspectjJar
		a.hasAopConfig = true
		a.context.Log.Info("AspectJ Weaver detected: %s with WEB-INF/classes/META-INF/aop.xml", aspectjJar)
		return "aspectj-weaver", nil
	}

	return "", nil
}

// Supply phase - nothing to install for AspectJ (app-provided JAR)
func (a *AspectJWeaverAgentFramework) Supply() error {
	a.context.Log.Info("AspectJ Weaver Agent detected - using application-provided JAR")
	return nil
}

// Finalize configures the AspectJ Weaver agent for runtime
func (a *AspectJWeaverAgentFramework) Finalize() error {
	a.context.Log.Info("Configuring AspectJ Weaver Agent")

	// Find JAR if not set (separate finalize instance)
	if a.aspectjJar == "" {
		jar, err := a.findAspectJWeaver()
		if err != nil || jar == "" {
			a.context.Log.Warning("AspectJ Weaver JAR not found during finalize")
			return nil
		}
		a.aspectjJar = jar
	}

	// Verify JAR exists at staging time
	if _, err := os.Stat(a.aspectjJar); err != nil {
		a.context.Log.Warning("AspectJ Weaver JAR not found: %s", a.aspectjJar)
		return nil
	}

	// Build runtime path using $HOME (app-provided JAR in BuildDir)
	relPath, err := filepath.Rel(a.context.Stager.BuildDir(), a.aspectjJar)
	if err != nil {
		return fmt.Errorf("failed to compute relative path: %w", err)
	}
	runtimeJarPath := filepath.Join("$HOME", relPath)

	// Build JAVA_OPTS with javaagent using runtime path
	javaOpts := fmt.Sprintf("-javaagent:%s", runtimeJarPath)

	// Write JAVA_OPTS to .opts file with priority 12 (Ruby buildpack line 46)
	if err := writeJavaOptsFile(a.context, 12, "aspectj_weaver", javaOpts); err != nil {
		return fmt.Errorf("failed to write java_opts file: %w", err)
	}

	a.context.Log.Debug("AspectJ Weaver Agent configured successfully (priority 12)")
	return nil
}

// findAspectJWeaver searches for aspectjweaver-*.jar in the application
func (a *AspectJWeaverAgentFramework) findAspectJWeaver() (string, error) {
	buildDir := a.context.Stager.BuildDir()

	// Common locations to check for AspectJ Weaver JAR
	searchDirs := []string{
		filepath.Join(buildDir, "WEB-INF", "lib"),
		filepath.Join(buildDir, "lib"),
		filepath.Join(buildDir, "BOOT-INF", "lib"), // Spring Boot
		buildDir, // Root directory
	}

	for _, dir := range searchDirs {
		if _, err := os.Stat(dir); err != nil {
			continue // Directory doesn't exist, skip
		}

		entries, err := os.ReadDir(dir)
		if err != nil {
			continue
		}

		for _, entry := range entries {
			if !entry.IsDir() && strings.HasPrefix(entry.Name(), "aspectjweaver-") && strings.HasSuffix(entry.Name(), ".jar") {
				jarPath := filepath.Join(dir, entry.Name())
				a.context.Log.Debug("Found AspectJ Weaver JAR: %s", jarPath)
				return jarPath, nil
			}
		}
	}

	return "", nil
}

func (a *AspectJWeaverAgentFramework) loadConfig() (*aspectjWeaverConfig, error) {
	// initialize default values
	ajwConfig := aspectjWeaverConfig{
		Enabled: true,
	}
	config := os.Getenv("JBP_CONFIG_ASPECTJ_WEAVER_AGENT")
	if config != "" {
		yamlHandler := common.YamlHandler{}
		err := yamlHandler.ValidateFields([]byte(config), &ajwConfig)
		if err != nil {
			a.context.Log.Warning("Unknown user config values: %s", err.Error())
		}
		// overlay JBP_CONFIG_ASPECTJ_WEAVER_AGENT over default values
		if err = yamlHandler.Unmarshal([]byte(config), &ajwConfig); err != nil {
			return nil, fmt.Errorf("failed to parse JBP_CONFIG_ASPECTJ_WEAVER_AGENT: %w", err)
		}
	}
	return &ajwConfig, nil
}

type aspectjWeaverConfig struct {
	Enabled bool `yaml:"enabled"`
}

// isEnabled checks if aspectj weaver agent is enabled
func (a *aspectjWeaverConfig) isEnabled() bool {
	return a.Enabled
}
