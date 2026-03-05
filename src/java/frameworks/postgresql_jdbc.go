package frameworks

import (
	"fmt"
	"path/filepath"
	"strings"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/libbuildpack"
)

// PostgresqlJdbcFramework implements PostgreSQL JDBC driver support
// Automatically installs PostgreSQL JDBC driver if a PostgreSQL service is bound
type PostgresqlJdbcFramework struct {
	context *common.Context
}

// NewPostgresqlJdbcFramework creates a new PostgreSQL JDBC framework instance
func NewPostgresqlJdbcFramework(ctx *common.Context) *PostgresqlJdbcFramework {
	return &PostgresqlJdbcFramework{context: ctx}
}

// Detect checks if PostgreSQL JDBC driver should be installed
func (p *PostgresqlJdbcFramework) Detect() (string, error) {
	// Check if PostgreSQL service is bound
	if !p.hasPostgresService() {
		return "", nil
	}

	// Don't install if driver is already present in application
	if p.hasPostgresDriver() {
		p.context.Log.Debug("PostgreSQL JDBC driver already present in application")
		return "", nil
	}

	return "PostgreSQL JDBC", nil
}

// Supply installs the PostgreSQL JDBC driver
func (p *PostgresqlJdbcFramework) Supply() error {
	p.context.Log.BeginStep("Installing PostgreSQL JDBC driver")

	// Get PostgreSQL JDBC dependency from manifest
	dep, err := p.context.Manifest.DefaultVersion("postgresql-jdbc")
	if err != nil {
		p.context.Log.Warning("Unable to determine PostgreSQL JDBC version, using default")
		dep = libbuildpack.Dependency{
			Name:    "postgresql-jdbc",
			Version: "42.7.0", // Fallback version
		}
	}

	// Install PostgreSQL JDBC JAR
	postgresqlDir := filepath.Join(p.context.Stager.DepDir(), "postgresql_jdbc")
	if err := p.context.Installer.InstallDependency(dep, postgresqlDir); err != nil {
		return fmt.Errorf("failed to install PostgreSQL JDBC driver: %w", err)
	}

	p.context.Log.Info("Installed PostgreSQL JDBC driver version %s", dep.Version)
	return nil
}

// Finalize adds PostgreSQL JDBC driver to classpath
func (p *PostgresqlJdbcFramework) Finalize() error {
	// Add the JAR to classpath
	postgresqlDir := filepath.Join(p.context.Stager.DepDir(), "postgresql_jdbc")
	jarPattern := filepath.Join(postgresqlDir, "postgresql-*.jar")

	matches, err := filepath.Glob(jarPattern)
	if err != nil || len(matches) == 0 {
		// JAR not found, might not have been installed
		return nil
	}

	depsIdx := p.context.Stager.DepsIdx()
	runtimePath := fmt.Sprintf("$DEPS_DIR/%s/postgresql_jdbc/%s", depsIdx, filepath.Base(matches[0]))

	profileScript := fmt.Sprintf("export CLASSPATH=\"%s:${CLASSPATH:-}\"\n", runtimePath)
	if err := p.context.Stager.WriteProfileD("postgresql_jdbc.sh", profileScript); err != nil {
		return fmt.Errorf("failed to write postgresql_jdbc.sh profile.d script: %w", err)
	}

	p.context.Log.Debug("PostgreSQL JDBC JAR will be added to classpath at runtime: %s", runtimePath)
	return nil
}

// hasPostgresService checks if a PostgreSQL service is bound
func (p *PostgresqlJdbcFramework) hasPostgresService() bool {
	vcapServices, err := GetVCAPServices()
	if err != nil {
		return false
	}

	// Use helper methods to check for PostgreSQL service
	// This checks service labels, tags, and service names
	hasPostgres := vcapServices.HasService("postgres") ||
		vcapServices.HasTag("postgres") ||
		vcapServices.HasServiceByNamePattern("postgres")

	if !hasPostgres {
		return false
	}

	// Verify the service has a 'uri' credential
	for _, services := range vcapServices {
		for _, service := range services {
			// Check if service name, label, or tags contain "postgres"
			nameMatch := strings.Contains(strings.ToLower(service.Name), "postgres")
			tagMatch := false

			for _, tag := range service.Tags {
				if strings.Contains(strings.ToLower(tag), "postgres") {
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

// hasPostgresDriver checks if PostgreSQL JDBC driver is already in the application
func (p *PostgresqlJdbcFramework) hasPostgresDriver() bool {
	// Look for postgresql-*.jar in the application
	patterns := []string{
		filepath.Join(p.context.Stager.BuildDir(), "**", "postgresql-*.jar"),
		filepath.Join(p.context.Stager.BuildDir(), "WEB-INF", "lib", "postgresql-*.jar"),
		filepath.Join(p.context.Stager.BuildDir(), "BOOT-INF", "lib", "postgresql-*.jar"),
		filepath.Join(p.context.Stager.BuildDir(), "lib", "postgresql-*.jar"),
	}

	for _, pattern := range patterns {
		matches, err := filepath.Glob(pattern)
		if err == nil && len(matches) > 0 {
			return true
		}
	}

	return false
}
