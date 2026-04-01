// Cloud Foundry Java Buildpack
// Copyright 2013-2020 the original author or authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package frameworks

import (
	"fmt"
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"path/filepath"
	"strings"
)

// MariaDBJDBCFramework represents the MariaDB JDBC framework
type MariaDBJDBCFramework struct {
	context *common.Context
	jarPath string
}

// NewMariaDBJDBCFramework creates a new MariaDB JDBC framework instance
func NewMariaDBJDBCFramework(ctx *common.Context) *MariaDBJDBCFramework {
	return &MariaDBJDBCFramework{context: ctx}
}

// Detect checks if MariaDB/MySQL JDBC should be installed
func (f *MariaDBJDBCFramework) Detect() (string, error) {
	// Check if MariaDB/MySQL service is bound
	if !f.hasMariaDBService() {
		f.context.Log.Debug("MariaDB JDBC: No MariaDB/MySQL service detected")
		return "", nil
	}

	// Check if driver already exists in app
	if f.hasExistingDriver() {
		f.context.Log.Debug("MariaDB JDBC: Driver already present in application")
		return "", nil
	}

	f.context.Log.Debug("MariaDB JDBC framework detected")
	return "maria-db-jdbc", nil
}

// Supply downloads and installs the MariaDB JDBC driver
func (f *MariaDBJDBCFramework) Supply() error {
	f.context.Log.Debug("Installing MariaDB JDBC driver")

	// Get dependency from manifest
	dep, err := f.context.Manifest.DefaultVersion("mariadb-jdbc")
	if err != nil {
		return fmt.Errorf("unable to find MariaDB JDBC in manifest: %w", err)
	}

	// Install to lib subdirectory
	mariadbDir := filepath.Join(f.context.Stager.DepDir(), "mariadb_jdbc")
	if err := f.context.Installer.InstallDependency(dep, mariadbDir); err != nil {
		return fmt.Errorf("failed to install MariaDB JDBC: %w", err)
	}

	// constructJarPath can be skipped here and do it only in finalize, but it can be left as a double check
	// if jar path exists after the dependency install
	err = f.constructJarPath(mariadbDir)
	if err != nil {
		return fmt.Errorf("jdbc jar not found during supply: %w", err)
	}

	f.context.Log.Info("MariaDB JDBC %s installed", dep.Version)
	return nil
}

// Finalize adds the MariaDB JDBC driver to the classpath
func (f *MariaDBJDBCFramework) Finalize() error {
	mariadbDir := filepath.Join(f.context.Stager.DepDir(), "mariadb_jdbc")
	err := f.constructJarPath(mariadbDir)
	if err != nil {
		return fmt.Errorf("jdbc jar not found during finalize: %w", err)
	}

	f.context.Log.BeginStep("Configuring MariaDB JDBC driver")

	depsIdx := f.context.Stager.DepsIdx()
	runtimePath := fmt.Sprintf("$DEPS_DIR/%s/mariadb_jdbc/%s", depsIdx, filepath.Base(f.jarPath))

	profileScript := fmt.Sprintf("export CLASSPATH=\"%s${CLASSPATH:+:$CLASSPATH}\"\n", runtimePath)
	if err := f.context.Stager.WriteProfileD("mariadb_jdbc.sh", profileScript); err != nil {
		f.context.Log.Warning("Failed to add MariaDB JDBC to CLASSPATH: %s", err)
		return nil // Non-blocking
	}

	f.context.Log.Debug("Maria JDBC will be added to classpath at runtime: %s", runtimePath)
	return nil
}

// hasMariaDBService checks if a MariaDB or MySQL service is bound
func (f *MariaDBJDBCFramework) hasMariaDBService() bool {
	vcapServices, err := GetVCAPServices()
	if err != nil {
		return false
	}

	// Use helper methods to check for MariaDB/MySQL service
	// This checks service labels, tags, and service names
	hasMySQL := vcapServices.HasService("mysql") ||
		vcapServices.HasTag("mysql") ||
		vcapServices.HasServiceByNamePattern("mysql")

	hasMariaDB := vcapServices.HasService("mariadb") ||
		vcapServices.HasTag("mariadb") ||
		vcapServices.HasServiceByNamePattern("mariadb")

	if !hasMySQL && !hasMariaDB {
		return false
	}

	// Verify the service has a 'uri' credential
	for _, services := range vcapServices {
		for _, service := range services {
			nameMatch := common.ContainsIgnoreCase(service.Name, "mysql") ||
				common.ContainsIgnoreCase(service.Name, "mariadb")
			tagMatch := false

			for _, tag := range service.Tags {
				if common.ContainsIgnoreCase(tag, "mysql") || common.ContainsIgnoreCase(tag, "mariadb") {
					tagMatch = true
					break
				}
			}

			if nameMatch || tagMatch {
				if _, hasURI := service.Credentials["uri"]; hasURI {
					return true
				}
			}
		}
	}

	return false
}

// hasExistingDriver checks if a MySQL/MariaDB JDBC driver already exists in the app
func (f *MariaDBJDBCFramework) hasExistingDriver() bool {
	// Check for various MySQL/MariaDB driver patterns
	driverPatterns := []string{
		"mariadb-java-client*.jar",
		"mysql-connector-j*.jar",
		"aws-mysql-jdbc*.jar",
	}

	for _, pattern := range driverPatterns {
		matches, err := filepath.Glob(filepath.Join(f.context.Stager.BuildDir(), "**", pattern))
		if err != nil {
			f.context.Log.Debug("Error globbing for %s: %s", pattern, err)
			continue
		}
		if len(matches) > 0 {
			f.context.Log.Debug("Found existing driver: %s", matches[0])
			return true
		}
	}

	// Also check common locations
	commonLocations := []string{
		filepath.Join(f.context.Stager.BuildDir(), "WEB-INF", "lib"),
		filepath.Join(f.context.Stager.BuildDir(), "lib"),
		filepath.Join(f.context.Stager.BuildDir(), "BOOT-INF", "lib"),
	}

	for _, location := range commonLocations {
		for _, pattern := range driverPatterns {
			// Use simpler pattern for filepath.Glob (no ** recursive)
			simplePattern := strings.Replace(pattern, "*", "", 1) // Remove first *
			matches, err := filepath.Glob(filepath.Join(location, simplePattern+"*"))
			if err != nil {
				continue
			}
			if len(matches) > 0 {
				f.context.Log.Debug("Found existing driver in %s: %s", location, matches[0])
				return true
			}
		}
	}

	return false
}

func (f *MariaDBJDBCFramework) constructJarPath(mariadbDir string) error {
	jarPattern := filepath.Join(mariadbDir, "mariadb-jdbc-*.jar")
	matches, err := filepath.Glob(jarPattern)
	if err != nil {
		return fmt.Errorf("failed to search for MariaDB JDBC JAR: %w", err)
	}
	if len(matches) == 0 {
		return fmt.Errorf("jdbc jar not found after installation in %s", mariadbDir)
	}
	f.jarPath = matches[0]
	return nil
}

func (m *MariaDBJDBCFramework) DependencyIdentifier() string {
	return "mariadb-jdbc"
}
