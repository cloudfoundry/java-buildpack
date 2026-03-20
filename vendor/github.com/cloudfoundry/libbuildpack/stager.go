package libbuildpack

import (
	"errors"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
)

const SENTINEL = "sentinel"

type Stager struct {
	buildDir   string
	cacheDir   string
	depsDir    string
	depsIdx    string
	profileDir string
	manifest   *Manifest
	log        *Logger
}

func NewStager(args []string, logger *Logger, manifest *Manifest) *Stager {
	buildDir := args[0]
	cacheDir := args[1]
	depsDir := ""
	depsIdx := ""
	profileDir := ""

	sentinelPath := filepath.Join(string(filepath.Separator), "home", "vcap", "app", ".cloudfoundry", SENTINEL)
	exists, err := FileExists(sentinelPath)
	if err != nil {
		logger.Error("Problem resolving V3 sentinel file: %v", err)
	} else if exists {
		panic("ERROR: You are running a V2 buildpack after a V3 buildpack. This is unsupported.")
	}

	if len(args) >= 4 {
		depsDir = args[2]
		depsIdx = args[3]
	}
	if len(args) >= 5 && args[4] != "" {
		profileDir = args[4]
	} else {
		profileDir = filepath.Join(buildDir, ".profile.d")
	}

	s := &Stager{buildDir: buildDir,
		cacheDir:   cacheDir,
		depsDir:    depsDir,
		depsIdx:    depsIdx,
		profileDir: profileDir,
		manifest:   manifest,
		log:        logger,
	}

	return s
}

func (s *Stager) Logger() *Logger {
	return s.log
}

func (s *Stager) DepsDir() string {
	return s.depsDir
}

func (s *Stager) DepDir() string {
	return filepath.Join(s.depsDir, s.depsIdx)
}

func (s *Stager) ProfileDir() string {
	return s.profileDir
}

func (s *Stager) WriteConfigYml(config interface{}) error {
	if config == nil {
		config = map[interface{}]interface{}{}
	}
	bpVersion, err := s.manifest.Version()
	if err != nil {
		return err
	}
	data := map[string]interface{}{"name": s.manifest.Language(), "config": config, "version": bpVersion}
	y := &YAML{}
	return y.Write(filepath.Join(s.DepDir(), "config.yml"), data)
}

func (s *Stager) WriteEnvFile(envVar, envVal string) error {
	envDir := filepath.Join(s.DepDir(), "env")

	if err := os.MkdirAll(envDir, 0755); err != nil {
		return err

	}

	return ioutil.WriteFile(filepath.Join(envDir, envVar), []byte(envVal), 0644)
}

func (s *Stager) LinkDirectoryInDepDir(destDir, depSubDir string) error {
	srcDir := filepath.Join(s.DepDir(), depSubDir)
	if err := os.MkdirAll(srcDir, 0755); err != nil {
		return err
	}

	files, err := ioutil.ReadDir(destDir)
	if err != nil {
		return err
	}

	for _, file := range files {
		relPath, err := filepath.Rel(srcDir, filepath.Join(destDir, file.Name()))
		if err != nil {
			return err
		}

		destPath := filepath.Join(srcDir, file.Name())
		if _, err := os.Lstat(destPath); err == nil {
			os.Remove(destPath)
		}

		if err := os.Symlink(relPath, filepath.Join(srcDir, file.Name())); err != nil {
			return err
		}
	}

	return nil
}

func (s *Stager) CheckBuildpackValid() error {
	version, err := s.manifest.Version()
	if err != nil {
		s.log.Error("Could not determine buildpack version: %s", err)
		return err
	}

	s.log.BeginStep("%s Buildpack version %s", strings.Title(s.manifest.Language()), version)

	err = s.manifest.CheckStackSupport()
	if err != nil {
		s.log.Error("Stack not supported by buildpack: %s", err)
		return err
	}

	s.manifest.CheckBuildpackVersion(s.cacheDir)

	return nil
}

func (s *Stager) StagingComplete() {
	s.manifest.StoreBuildpackMetadata(s.cacheDir)
}

func (s *Stager) ClearCache() error {
	files, err := ioutil.ReadDir(s.cacheDir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}

	for _, file := range files {
		err = os.RemoveAll(filepath.Join(s.cacheDir, file.Name()))
		if err != nil {
			return err
		}
	}

	return nil
}

func (s *Stager) ClearDepDir() error {
	files, err := ioutil.ReadDir(s.DepDir())
	if err != nil {
		return err
	}

	for _, file := range files {
		if file.Name() != "config.yml" {
			if err := os.RemoveAll(filepath.Join(s.DepDir(), file.Name())); err != nil {
				return err
			}
		}
	}

	return nil
}

func (s *Stager) WriteProfileD(scriptName, scriptContents string) error {
	profileDir := filepath.Join(s.DepDir(), "profile.d")

	err := os.MkdirAll(profileDir, 0755)
	if err != nil {
		return err
	}

	return writeToFile(strings.NewReader(scriptContents), filepath.Join(profileDir, scriptName), 0755)
}

func (s *Stager) BuildDir() string {
	return s.buildDir
}

func (s *Stager) CacheDir() string {
	return s.cacheDir
}

func (s *Stager) DepsIdx() string {
	return s.depsIdx
}

func (s *Stager) SetStagingEnvironment() error {
	for envVar, dir := range stagingEnvVarDirs {
		oldVal := os.Getenv(envVar)

		depsPaths, err := existingDepsDirs(s.depsDir, dir, s.depsDir)
		if err != nil {
			return err
		}

		if len(depsPaths) != 0 {
			if len(oldVal) > 0 {
				depsPaths = append(depsPaths, oldVal)
			}
			os.Setenv(envVar, strings.Join(depsPaths, envPathSeparator))
		}
	}

	depsPaths, err := existingDepsDirs(s.depsDir, "env", s.depsDir)
	if err != nil {
		return err
	}

	for _, dir := range depsPaths {
		files, err := ioutil.ReadDir(dir)
		if err != nil {
			return err
		}

		for _, file := range files {
			if file.Mode().IsRegular() {
				val, err := ioutil.ReadFile(filepath.Join(dir, file.Name()))
				if err != nil {
					return err
				}

				if err := os.Setenv(file.Name(), string(val)); err != nil {
					return err
				}
			}
		}
	}

	return nil
}

func (s *Stager) SetLaunchEnvironment() error {
	scriptContents := ""

	for envVar, dir := range launchEnvVarDirs {
		depsPaths, err := existingDepsDirs(s.depsDir, dir, depsDirEnvVar)
		if err != nil {
			return err
		}

		if len(depsPaths) != 0 {
			scriptContents += fmt.Sprintf(scriptLineTemplate, envVar, strings.Join(depsPaths, envPathSeparator))
			scriptContents += "\n"
		}
	}

	if err := os.MkdirAll(s.profileDir, 0755); err != nil {
		return err
	}

	scriptLocation := filepath.Join(s.ProfileDir(), scriptName)
	if err := writeToFile(strings.NewReader(scriptContents), scriptLocation, 0755); err != nil {
		return err
	}

	profileDirs, err := existingDepsDirs(s.depsDir, "profile.d", s.depsDir)
	if err != nil {
		return err
	}

	for _, dir := range profileDirs {
		sections := strings.Split(dir, string(filepath.Separator))
		if len(sections) < 2 {
			return errors.New("invalid dep dir")
		}

		depsIdx := sections[len(sections)-2]

		files, err := ioutil.ReadDir(dir)
		if err != nil {
			return err
		}

		for _, file := range files {
			if file.Mode().IsRegular() {
				src := filepath.Join(dir, file.Name())
				dest := filepath.Join(s.profileDir, depsIdx+"_"+file.Name())

				if err := CopyFile(src, dest); err != nil {
					return err
				}
			}
		}
	}

	return nil
}

func (s *Stager) BuildpackLanguage() string {
	return s.manifest.Language()
}

func (s *Stager) BuildpackVersion() (string, error) {
	return s.manifest.Version()
}

func existingDepsDirs(depsDir, subDir, prefix string) ([]string, error) {
	files, err := ioutil.ReadDir(depsDir)
	if err != nil {
		return nil, err
	}

	var existingDirs []string

	for _, file := range files {
		if !file.IsDir() {
			continue
		}

		filesystemDir := filepath.Join(depsDir, file.Name(), subDir)
		dirToJoin := filepath.Join(prefix, file.Name(), subDir)

		addToDirs, err := FileExists(filesystemDir)
		if err != nil {
			return nil, err
		}

		if addToDirs {
			existingDirs = append([]string{dirToJoin}, existingDirs...)
		}
	}

	return existingDirs, nil
}
