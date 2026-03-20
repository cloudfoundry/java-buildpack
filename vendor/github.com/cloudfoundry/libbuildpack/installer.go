package libbuildpack

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/Masterminds/semver"
)

type Installer struct {
	manifest                 *Manifest
	appCacheDir              string
	filesInAppCache          map[string]interface{}
	versionLine              *map[string]string
	retryTimeLimit           time.Duration
	retryTimeInitialInterval time.Duration
}

func NewInstaller(manifest *Manifest) *Installer {
	return &Installer{manifest, "", make(map[string]interface{}), &map[string]string{}, 1 * time.Minute, 1 * time.Second}
}

func (i *Installer) SetAppCacheDir(appCacheDir string) (err error) {
	i.appCacheDir, err = filepath.Abs(filepath.Join(appCacheDir, "dependencies"))
	return
}

func (i *Installer) InstallDependency(dep Dependency, outputDir string) error {
	return i.InstallDependencyWithStrip(dep, outputDir, 0)
}

// InstallDependencyWithStrip installs a dependency with optional path stripping
// stripComponents works like tar's --strip-components flag:
//
//	0 = extract as-is (default, same as InstallDependency)
//	1 = remove top-level directory
//	2 = remove two levels, etc.
//
// This is useful for archives that extract to a top-level directory
// (e.g., apache-tomcat-9.0.98.tar.gz extracts to apache-tomcat-9.0.98/)
func (i *Installer) InstallDependencyWithStrip(dep Dependency, outputDir string, stripComponents int) error {
	i.manifest.log.BeginStep("Installing %s %s", dep.Name, dep.Version)

	tmpDir, err := ioutil.TempDir("", "downloads")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmpDir)

	tmpFile := filepath.Join(tmpDir, "archive")

	entry, err := i.manifest.GetEntry(dep)
	if err != nil {
		return err
	}

	err = i.FetchDependency(dep, tmpFile)
	if err != nil {
		return err
	}

	err = i.warnNewerPatch(dep)
	if err != nil {
		return err
	}

	err = i.warnEndOfLife(dep)
	if err != nil {
		return err
	}

	if strings.HasSuffix(entry.URI, ".sh") {
		return os.Rename(tmpFile, outputDir)
	}

	err = os.MkdirAll(outputDir, 0755)
	if err != nil {
		return err
	}

	if strings.HasSuffix(entry.URI, ".zip") {
		if stripComponents > 0 {
			return ExtractZipWithStrip(tmpFile, outputDir, stripComponents)
		}
		return ExtractZip(tmpFile, outputDir)
	}

	if strings.HasSuffix(entry.URI, ".tar.xz") {
		if stripComponents > 0 {
			return ExtractTarXzWithStrip(tmpFile, outputDir, stripComponents)
		}
		return ExtractTarXz(tmpFile, outputDir)
	}

	if strings.HasSuffix(entry.URI, ".tar.gz") || strings.HasSuffix(entry.URI, ".tgz") {
		if stripComponents > 0 {
			return ExtractTarGzWithStrip(tmpFile, outputDir, stripComponents)
		}
		return ExtractTarGz(tmpFile, outputDir)
	}

	basename := filepath.Base(entry.URI)
	return CopyFile(tmpFile, filepath.Join(outputDir, basename))
}

func (i *Installer) warnNewerPatch(dep Dependency) error {

	v, err := semver.NewVersion(dep.Version)
	if err != nil {
		return nil
	}

	if v.Prerelease() != "" {
		i.manifest.log.Warning("You are using the pre-release version %s of %s", dep.Version, dep.Name)
		return nil
	}

	versions := i.manifest.AllDependencyVersions(dep.Name)

	minor := fmt.Sprintf("%v", v.Minor())
	versionLine := *i.GetVersionLine()
	if versionLine[dep.Name] == "minor" {
		minor = "x"
	}
	constraint := fmt.Sprintf("%d.%s.x", v.Major(), minor)

	latest, err := FindMatchingVersion(constraint, versions)
	if err != nil {
		return err
	}

	if latest != dep.Version {
		i.manifest.log.Warning(outdatedDependencyWarning(dep, latest))
	}

	return nil
}

func (i *Installer) warnEndOfLife(dep Dependency) error {
	matchVersion := func(versionLine, depVersion string) bool {
		return versionLine == depVersion
	}

	v, err := semver.NewVersion(dep.Version)
	if err == nil {
		matchVersion = func(versionLine, depVersion string) bool {
			constraint, err := semver.NewConstraint(versionLine)
			if err != nil {
				return false
			}

			return constraint.Check(v)
		}
	}

	for _, deprecation := range i.manifest.Deprecations {
		if deprecation.Name != dep.Name {
			continue
		}
		if !matchVersion(deprecation.VersionLine, dep.Version) {
			continue
		}

		eolTime, err := time.Parse(dateFormat, deprecation.Date)
		if err != nil {
			return err
		}

		if eolTime.Sub(i.manifest.currentTime) < thirtyDays {
			i.manifest.log.Warning(endOfLifeWarning(dep.Name, deprecation.VersionLine, deprecation.Date, deprecation.Link))
		}
	}
	return nil
}

func (i *Installer) FetchDependency(dep Dependency, outputFile string) error {
	entry, err := i.manifest.GetEntry(dep)
	if err != nil {
		return err
	}

	if entry.File != "" { // this file is cached by the buildpack
		return fetchCachedBuildpackDependency(entry, outputFile, i.manifest.manifestRootDir, i.manifest.log)
	}

	if i.appCacheDir != "" { // this buildpack caches dependencies in the app cache
		return i.fetchAppCachedBuildpackDependency(entry, outputFile)
	}

	return downloadDependency(entry, outputFile, i.manifest.log, i.retryTimeLimit, i.retryTimeInitialInterval)
}

func (i *Installer) CleanupAppCache() error {
	pathsToDelete := []string{}

	if err := filepath.Walk(i.appCacheDir, func(path string, info os.FileInfo, err error) error {
		if info == nil || info.IsDir() {
			return nil
		}
		if err != nil {
			return fmt.Errorf("Failed while cleaning up app cache; couldn't look at %s because: %v", path, err)
		}
		if path == i.appCacheDir {
			return nil
		}
		if _, ok := i.filesInAppCache[path]; !ok {
			pathsToDelete = append(pathsToDelete, path)
		}
		return nil
	}); err != nil {
		return err
	}

	for _, path := range pathsToDelete {
		i.manifest.log.Debug("Deleting cached file: %s", path)
		if err := os.RemoveAll(path); err != nil {
			return fmt.Errorf("Failed while cleaning up app cache; couldn't delete %s because: %v", path, err)
		}
	}

	return nil
}

func (i *Installer) InstallOnlyVersion(depName string, installDir string) error {
	return i.InstallOnlyVersionWithStrip(depName, installDir, 0)
}

// InstallOnlyVersionWithStrip installs the only version of a dependency with optional path stripping
func (i *Installer) InstallOnlyVersionWithStrip(depName string, installDir string, stripComponents int) error {
	depVersions := i.manifest.AllDependencyVersions(depName)

	if len(depVersions) > 1 {
		return fmt.Errorf("more than one version of %s found", depName)
	} else if len(depVersions) == 0 {
		return fmt.Errorf("no versions of %s found", depName)
	}

	dep := Dependency{Name: depName, Version: depVersions[0]}
	return i.InstallDependencyWithStrip(dep, installDir, stripComponents)
}

func (i *Installer) fetchAppCachedBuildpackDependency(entry *ManifestEntry, outputFile string) error {
	shaURI := sha256.Sum256([]byte(entry.URI))
	cacheFile := filepath.Join(i.appCacheDir, hex.EncodeToString(shaURI[:]), filepath.Base(entry.URI))

	i.filesInAppCache[cacheFile] = true
	i.filesInAppCache[filepath.Dir(cacheFile)] = true

	foundCacheFile, err := FileExists(cacheFile)
	if err != nil {
		return err
	}

	if foundCacheFile {
		i.manifest.log.Info("Copy [%s]", cacheFile)
		if err := CopyFile(cacheFile, outputFile); err != nil {
			return err
		}
		return deleteBadFile(entry, outputFile)
	}

	if err := downloadDependency(entry, outputFile, i.manifest.log, i.retryTimeLimit, i.retryTimeInitialInterval); err != nil {
		return err
	}
	if err := CopyFile(outputFile, cacheFile); err != nil {
		return err
	}

	return nil
}

func (i *Installer) SetVersionLine(depName string, line string) {
	(*i.versionLine)[depName] = line
}

func (i *Installer) GetVersionLine() *map[string]string {
	return i.versionLine
}

func (i *Installer) SetRetryTimeLimit(duration time.Duration) {
	i.retryTimeLimit = duration
	return
}

func (i *Installer) SetRetryTimeInitialInterval(duration time.Duration) {
	i.retryTimeInitialInterval = duration
	return
}
