package jres

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
)

// BaseJRE provides the shared implementation for all standard JRE providers.
// Variation between JREs is injected via fields — implementers never override
// Supply/Finalize, avoiding the "forgot to call base" footgun.
type BaseJRE struct {
	ctx              *common.Context
	jreDir           string
	version          string
	javaHome         string
	memoryCalc       *MemoryCalculator
	jvmkill          *JVMKillAgent
	installedVersion string

	jreName        string
	jreKey         string
	dirPrefixes    []string
	dirExacts      []string
	installErrNote string

	extraFinalizeOpts func() string
}

func newBaseJRE(ctx *common.Context, jreName, jreKey string, dirPrefixes, dirExacts []string, installErrNote string) BaseJRE {
	return BaseJRE{
		ctx:            ctx,
		jreDir:         filepath.Join(ctx.Stager.DepDir(), "jre"),
		jreName:        jreName,
		jreKey:         jreKey,
		dirPrefixes:    dirPrefixes,
		dirExacts:      dirExacts,
		installErrNote: installErrNote,
	}
}

func (b *BaseJRE) Name() string {
	return b.jreName
}

func (b *BaseJRE) Detect() (bool, error) {
	return DetectJREByEnv(b.jreKey), nil
}

func (b *BaseJRE) Supply() error {
	b.ctx.Log.BeginStep("Installing %s", b.jreName)

	dep, err := GetJREVersion(b.ctx, b.jreKey)
	if err != nil {
		return fmt.Errorf("failed to determine %s version from manifest: %w", b.jreName, err)
	}

	b.version = dep.Version
	b.ctx.Log.Info("Installing %s (%s)", b.jreName, b.version)

	if err := b.ctx.Installer.InstallDependency(dep, b.jreDir); err != nil {
		if b.installErrNote != "" {
			return fmt.Errorf("failed to install %s: %w %s", b.jreName, err, b.installErrNote)
		}
		return fmt.Errorf("failed to install %s: %w", b.jreName, err)
	}

	javaHome, err := b.findJavaHome()
	if err != nil {
		return fmt.Errorf("failed to find JAVA_HOME: %w", err)
	}
	b.javaHome = javaHome
	b.installedVersion = b.version

	if err := b.writeProfileDScript(); err != nil {
		b.ctx.Log.Warning("Could not write java.sh profile.d script: %s", err.Error())
	} else {
		b.ctx.Log.Debug("Created profile.d script: java.sh")
	}

	if err := b.ctx.Stager.WriteEnvFile("JAVA_HOME", javaHome); err != nil {
		b.ctx.Log.Warning("Could not write JAVA_HOME env file: %s", err.Error())
	}

	javaBin := filepath.Join(javaHome, "bin", "java")
	if err := b.ctx.Stager.AddBinDependencyLink(javaBin, "java"); err != nil {
		b.ctx.Log.Warning("Could not add java bin dependency link: %s", err.Error())
	}

	libDir := filepath.Join(javaHome, "lib")
	if _, err := os.Stat(libDir); err == nil {
		if err := b.ctx.Stager.LinkDirectoryInDepDir(libDir, "lib"); err != nil {
			b.ctx.Log.Warning("Could not link JRE lib directory: %s", err.Error())
		}
	}

	javaMajorVersion, err := common.DetermineJavaVersion(javaHome)
	if err != nil {
		b.ctx.Log.Warning("Could not determine Java version: %s", err.Error())
		javaMajorVersion = 17
	}
	b.ctx.Log.Info("Detected Java major version: %d", javaMajorVersion)

	b.jvmkill = NewJVMKillAgent(b.ctx, b.jreDir, b.version)
	if err := b.jvmkill.Supply(); err != nil {
		b.ctx.Log.Warning("Failed to install JVMKill agent: %s (continuing)", err.Error())
	}

	b.memoryCalc = NewMemoryCalculator(b.ctx, b.jreDir, b.version, javaMajorVersion, b.jreKey)
	if err := b.memoryCalc.Supply(); err != nil {
		b.ctx.Log.Warning("Failed to install Memory Calculator: %s (continuing)", err.Error())
	}

	b.ctx.Log.Info("%s installation complete", b.jreName)
	return nil
}

func (b *BaseJRE) Finalize() error {
	b.ctx.Log.BeginStep("Finalizing %s configuration", b.jreName)

	if b.javaHome == "" {
		javaHome, err := b.findJavaHome()
		if err != nil {
			b.ctx.Log.Warning("Failed to find JAVA_HOME: %s", err.Error())
		} else {
			b.javaHome = javaHome
		}
	}

	if b.javaHome != "" {
		if err := os.Setenv("JAVA_HOME", b.javaHome); err != nil {
			b.ctx.Log.Warning("Failed to set JAVA_HOME environment variable: %s", err.Error())
		} else {
			b.ctx.Log.Debug("Set JAVA_HOME=%s", b.javaHome)
		}
	}

	javaMajorVersion := 17
	if b.javaHome != "" {
		if ver, err := common.DetermineJavaVersion(b.javaHome); err == nil {
			javaMajorVersion = ver
		}
	}

	if b.jvmkill == nil {
		b.jvmkill = NewJVMKillAgent(b.ctx, b.jreDir, b.version)
	}
	if err := b.jvmkill.Finalize(); err != nil {
		b.ctx.Log.Warning("Failed to finalize JVMKill agent: %s", err.Error())
	}

	baseOpts := []string{
		"-Djava.io.tmpdir=$TMPDIR",
		"-XX:ActiveProcessorCount=$(nproc)",
	}
	if err := WriteJavaOpts(b.ctx, strings.Join(baseOpts, " ")); err != nil {
		b.ctx.Log.Warning("Failed to write base JAVA_OPTS: %s", err.Error())
	}

	if b.memoryCalc == nil {
		b.memoryCalc = NewMemoryCalculator(b.ctx, b.jreDir, b.version, javaMajorVersion, b.jreKey)
	}
	if err := b.memoryCalc.Finalize(); err != nil {
		b.ctx.Log.Warning("Failed to finalize Memory Calculator: %s", err.Error())
	}

	if b.extraFinalizeOpts != nil {
		if extraOpts := b.extraFinalizeOpts(); extraOpts != "" {
			if err := WriteJavaOpts(b.ctx, extraOpts); err != nil {
				b.ctx.Log.Warning("Failed to write %s JAVA_OPTS: %s", b.jreName, err.Error())
			}
		}
	}

	b.ctx.Log.Info("%s finalization complete", b.jreName)
	return nil
}

func (b *BaseJRE) JavaHome() string {
	return b.javaHome
}

func (b *BaseJRE) Version() string {
	return b.installedVersion
}

func (b *BaseJRE) MemoryCalculatorCommand() string {
	if b.memoryCalc == nil {
		return ""
	}
	return b.memoryCalc.GetCalculatorCommand()
}

func (b *BaseJRE) findJavaHome() (string, error) {
	entries, err := os.ReadDir(b.jreDir)
	if err != nil {
		return "", fmt.Errorf("failed to read JRE directory: %w", err)
	}

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		name := entry.Name()
		matches := false
		for _, prefix := range b.dirPrefixes {
			if strings.HasPrefix(name, prefix) {
				matches = true
				break
			}
		}
		if !matches {
			for _, exact := range b.dirExacts {
				if name == exact {
					matches = true
					break
				}
			}
		}
		if !matches {
			continue
		}

		path := filepath.Join(b.jreDir, name)
		if _, err := os.Stat(filepath.Join(path, "bin", "java")); err == nil {
			return path, nil
		}
	}

	if _, err := os.Stat(filepath.Join(b.jreDir, "bin", "java")); err == nil {
		return b.jreDir, nil
	}

	return "", fmt.Errorf("could not find valid JAVA_HOME in %s", b.jreDir)
}

func (b *BaseJRE) writeProfileDScript() error {
	return WriteJavaHomeProfileD(b.ctx, b.jreDir, b.javaHome)
}
