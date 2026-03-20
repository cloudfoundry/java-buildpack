// +build !windows

package libbuildpack

import (
	"os"
	"path/filepath"
)

const (
	envPathSeparator   = ":"
	depsDirEnvVar      = "$DEPS_DIR"
	scriptName         = "000_multi-supply.sh"
	scriptLineTemplate = `export %[1]s=%[2]s$([[ ! -z "${%[1]s:-}" ]] && echo ":$%[1]s")`
)

var stagingEnvVarDirs = map[string]string{
	"PATH":            "bin",
	"LD_LIBRARY_PATH": "lib",
	"LIBRARY_PATH":    "lib",
	"CPATH":           "include",
	"PKG_CONFIG_PATH": "pkgconfig",
}

var launchEnvVarDirs = map[string]string{
	"PATH":            "bin",
	"LD_LIBRARY_PATH": "lib",
	"LIBRARY_PATH":    "lib",
}

func (s *Stager) AddBinDependencyLink(destPath, sourceName string) error {
	binDir := filepath.Join(s.DepDir(), "bin")

	if err := os.MkdirAll(binDir, 0755); err != nil {
		return err
	}

	relPath, err := filepath.Rel(binDir, destPath)
	if err != nil {
		return err
	}

	return os.Symlink(relPath, filepath.Join(binDir, sourceName))
}
