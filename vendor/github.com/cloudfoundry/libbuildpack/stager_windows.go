// +build windows

package libbuildpack

import (
	"os"
	"path/filepath"
)

const (
	envPathSeparator   = ";"
	depsDirEnvVar      = "%DEPS_DIR%"
	scriptName         = "000_multi-supply.bat"
	scriptLineTemplate = `set %[1]s=%[2]s;%%%[1]s%%`
)

var stagingEnvVarDirs = map[string]string{
	"PATH": "bin",
}

var launchEnvVarDirs = map[string]string{
	"PATH": "bin",
}

func (s *Stager) AddBinDependencyLink(destPath, sourceName string) error {
	binDir := filepath.Join(s.DepDir(), "bin")

	if err := os.MkdirAll(binDir, 0755); err != nil {
		return err
	}

	return os.Link(destPath, filepath.Join(binDir, sourceName))
}
