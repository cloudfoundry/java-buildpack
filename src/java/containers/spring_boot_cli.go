package containers

import (
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// SpringBootCLIContainer handles Spring Boot CLI applications
type SpringBootCLIContainer struct {
	context     *common.Context
	groovyFiles []string
	groovyUtils *GroovyUtils
}

// NewSpringBootCLIContainer creates a new Spring Boot CLI container
func NewSpringBootCLIContainer(ctx *common.Context) *SpringBootCLIContainer {
	return &SpringBootCLIContainer{
		context:     ctx,
		groovyUtils: &GroovyUtils{},
	}
}

// Detect checks if this is a Spring Boot CLI application
func (s *SpringBootCLIContainer) Detect() (string, error) {
	buildDir := s.context.Stager.BuildDir()

	// Find all Groovy files (excluding logback config files)
	allGroovyFiles, err := s.groovyUtils.FindGroovyFiles(buildDir)
	if err != nil {
		return "", err
	}

	var groovyFiles []string
	for _, file := range allGroovyFiles {
		if !s.groovyUtils.IsLogbackConfigFile(file) && isValidGroovyFile(file) {
			groovyFiles = append(groovyFiles, file)
		}
	}

	// Must have at least one Groovy file
	if len(groovyFiles) == 0 {
		return "", nil
	}

	// All Groovy files must be POGO or beans configuration
	if !s.allPOGOOrConfiguration(groovyFiles) {
		return "", nil
	}

	// No Groovy file should have a main() method
	if !s.noMainMethod(groovyFiles) {
		return "", nil
	}

	// No Groovy file should have a shebang
	if !s.noShebang(groovyFiles) {
		return "", nil
	}

	// All checks passed - this is a Spring Boot CLI application
	s.groovyFiles = groovyFiles
	s.context.Log.Debug("Detected Spring Boot CLI application with %d Groovy file(s)", len(groovyFiles))
	return "Spring Boot CLI", nil
}

// Supply installs Spring Boot CLI
func (s *SpringBootCLIContainer) Supply() error {
	s.context.Log.BeginStep("Supplying Spring Boot CLI")

	// Install Spring Boot CLI runtime
	dep, err := s.context.Manifest.DefaultVersion("spring-boot-cli")
	if err != nil {
		s.context.Log.Warning("Unable to determine default Spring Boot CLI version: %s", err.Error())
		// Fallback version
		dep.Name = "spring-boot-cli"
		dep.Version = "2.7.0"
	}

	springBootCLIDir := filepath.Join(s.context.Stager.DepDir(), "spring-boot-cli")
	// Strip top-level directory from archive (e.g., spring-2.7.0/)
	if err := s.context.Installer.InstallDependencyWithStrip(dep, springBootCLIDir, 1); err != nil {
		return fmt.Errorf("failed to install Spring Boot CLI: %w", err)
	}

	s.context.Log.Info("Installed Spring Boot CLI version %s", dep.Version)

	// Write profile.d script to set SPRING_BOOT_CLI_HOME at runtime
	// At runtime, CF sets $DEPS_DIR (e.g., /home/vcap/deps) and makes dependencies available at $DEPS_DIR/<idx>/
	depsIdx := s.context.Stager.DepsIdx()
	envContent := fmt.Sprintf(`export SPRING_BOOT_CLI_HOME=$DEPS_DIR/%s/spring-boot-cli
`, depsIdx)

	if err := s.context.Stager.WriteProfileD("spring-boot-cli.sh", envContent); err != nil {
		s.context.Log.Warning("Could not write spring-boot-cli.sh profile.d script: %s", err.Error())
	} else {
		s.context.Log.Debug("Created profile.d script: spring-boot-cli.sh")
	}

	return nil
}

// Finalize performs final Spring Boot CLI configuration
func (s *SpringBootCLIContainer) Finalize() error {
	s.context.Log.BeginStep("Finalizing Spring Boot CLI")

	// Set environment variables for Spring Boot CLI
	envVars := map[string]string{
		"JAVA_OPTS":   "$JAVA_OPTS",
		"SERVER_PORT": "$PORT",
	}

	for key, value := range envVars {
		if err := s.context.Stager.WriteEnvFile(key, value); err != nil {
			s.context.Log.Warning("Failed to set %s: %s", key, err.Error())
		}
	}

	return nil
}

// Release returns the Spring Boot CLI startup command
func (s *SpringBootCLIContainer) Release() (string, error) {
	buildDir := s.context.Stager.BuildDir()

	// Use environment variable set by profile.d script (created during Supply)
	springBootCLIDir := "$SPRING_BOOT_CLI_HOME"

	// Build classpath from additional libraries and root libraries
	var classpathParts []string

	// Add additional libraries (if any)
	additionalLibs := filepath.Join(buildDir, ".additional_libs")
	if info, err := os.Stat(additionalLibs); err == nil && info.IsDir() {
		classpathParts = append(classpathParts, ".additional_libs/*")
	}

	// Add root libraries (lib/ directory)
	rootLibs := filepath.Join(buildDir, "lib")
	if info, err := os.Stat(rootLibs); err == nil && info.IsDir() {
		classpathParts = append(classpathParts, "lib/*")
	}

	classpath := ""
	if len(classpathParts) > 0 {
		classpath = strings.Join(classpathParts, ":")
	}

	// Get relative paths for Groovy files
	var relativeGroovyFiles []string
	for _, file := range s.groovyFiles {
		relPath, err := filepath.Rel(buildDir, file)
		if err != nil {
			relPath = filepath.Base(file)
		}
		relativeGroovyFiles = append(relativeGroovyFiles, relPath)
	}

	// Build the spring run command
	springBin := fmt.Sprintf("%s/bin/spring", springBootCLIDir)

	var cmdParts []string
	cmdParts = append(cmdParts, springBin, "run")

	// Add classpath if present
	if classpath != "" {
		cmdParts = append(cmdParts, "--classpath", classpath)
	}

	// Add Groovy files
	cmdParts = append(cmdParts, relativeGroovyFiles...)

	cmd := strings.Join(cmdParts, " ")
	s.context.Log.Debug("Spring Boot CLI command: %s", cmd)

	return cmd, nil
}

// Helper methods

// allPOGOOrConfiguration checks if all Groovy files are POGO or beans configuration
func (s *SpringBootCLIContainer) allPOGOOrConfiguration(files []string) bool {
	for _, file := range files {
		if !s.groovyUtils.IsPOGO(file) && !s.groovyUtils.IsBeans(file) {
			s.context.Log.Debug("File %s is neither POGO nor beans configuration", file)
			return false
		}
	}
	return true
}

// noMainMethod checks that no Groovy file has a main() method
func (s *SpringBootCLIContainer) noMainMethod(files []string) bool {
	for _, file := range files {
		if s.groovyUtils.HasMainMethod(file) {
			s.context.Log.Debug("File %s has a main() method", file)
			return false
		}
	}
	return true
}

// noShebang checks that no Groovy file has a shebang
func (s *SpringBootCLIContainer) noShebang(files []string) bool {
	for _, file := range files {
		if s.groovyUtils.HasShebang(file) {
			s.context.Log.Debug("File %s has a shebang", file)
			return false
		}
	}
	return true
}
