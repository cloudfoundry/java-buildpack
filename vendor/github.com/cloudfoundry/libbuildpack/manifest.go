package libbuildpack

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const dateFormat = "2006-01-02"
const thirtyDays = time.Hour * 24 * 30

const (
	CFLINUXFS2              = "cflinuxfs2"
	WINDOWS2016             = "windows2016"
	ATTENTION_MSG           = "!! !!"
	WARNING_MSG_CFLINUXFS2  = "This application is being deployed on cflinuxfs2 which is being deprecated in April, 2019.\nPlease migrate this application to cflinuxfs3.\nFor more information about changing the stack, see https://docs.cloudfoundry.org/devguide/deploy-apps/stacks.html"
	WARNING_MSG_WINDOWS2016 = "This application is being deployed on the 'windows2016' stack which is deprecated.\nPlease restage this application to the 'windows' stack with '-s windows'.\nAny other applications deployed to the 'windows2016' stack should also be restaged to '-s windows'.\nFor more information, see https://docs.cloudfoundry.org/devguide/deploy-apps/windows-stacks.html"
)

type Dependency struct {
	Name    string `yaml:"name"`
	Version string `yaml:"version"`
}

type DeprecationDate struct {
	Name        string `yaml:"name"`
	VersionLine string `yaml:"version_line"`
	Date        string `yaml:"date"`
	Link        string `yaml:"link"`
}

type ManifestEntry struct {
	Dependency Dependency `yaml:",inline"`
	URI        string     `yaml:"uri"`
	File       string     `yaml:"file"`
	SHA256     string     `yaml:"sha256"`
	CFStacks   []string   `yaml:"cf_stacks"`
}

type Manifest struct {
	LanguageString  string            `yaml:"language"`
	DefaultVersions []Dependency      `yaml:"default_versions"`
	ManifestEntries []ManifestEntry   `yaml:"dependencies"`
	Deprecations    []DeprecationDate `yaml:"dependency_deprecation_dates"`
	Stack           string            `yaml:"stack"`
	manifestRootDir string
	currentTime     time.Time //move into installer?
	log             *Logger
}

type BuildpackMetadata struct {
	Language string `yaml:"language"`
	Version  string `yaml:"version"`
}

func NewManifest(bpDir string, logger *Logger, currentTime time.Time) (*Manifest, error) {
	var m Manifest
	y := &YAML{}

	err := y.Load(filepath.Join(bpDir, "manifest.yml"), &m)
	if err != nil {
		return nil, err
	}

	m.manifestRootDir, err = filepath.Abs(bpDir)
	if err != nil {
		return nil, err
	}

	m.currentTime = currentTime
	m.log = logger

	return &m, nil
}

func (m *Manifest) replaceDefaultVersion(oDep Dependency) {
	replaced := false
	for idx, mDep := range m.DefaultVersions {
		if mDep.Name == oDep.Name {
			replaced = true
			m.DefaultVersions[idx] = oDep
		}
	}
	if !replaced {
		m.DefaultVersions = append(m.DefaultVersions, oDep)
	}
}
func (m *Manifest) replaceManifestEntry(oEntry ManifestEntry) {
	oDep := oEntry.Dependency
	replaced := false
	for idx, mEntry := range m.ManifestEntries {
		mDep := mEntry.Dependency
		if mDep.Name == oDep.Name && mDep.Version == oDep.Version {
			replaced = true
			m.ManifestEntries[idx] = mEntry
		}
	}
	if !replaced {
		m.ManifestEntries = append(m.ManifestEntries, oEntry)
	}
}

func (m *Manifest) ApplyOverride(depsDir string) error {
	files, err := filepath.Glob(filepath.Join(depsDir, "*", "override.yml"))
	if err != nil {
		return err
	}

	for _, file := range files {
		var overrideYml map[string]Manifest
		y := &YAML{}
		if err := y.Load(file, &overrideYml); err != nil {
			return err
		}

		if o, found := overrideYml[m.Language()]; found {
			for _, oDep := range o.DefaultVersions {
				m.replaceDefaultVersion(oDep)
			}
			for _, oEntry := range o.ManifestEntries {
				m.replaceManifestEntry(oEntry)
			}
		}
	}

	return nil
}

func (m *Manifest) RootDir() string {
	return m.manifestRootDir
}

func (m *Manifest) CheckBuildpackVersion(cacheDir string) {
	var md BuildpackMetadata
	y := &YAML{}

	err := y.Load(filepath.Join(cacheDir, "BUILDPACK_METADATA"), &md)
	if err != nil {
		return
	}

	if md.Language != m.Language() {
		return
	}

	version, err := m.Version()
	if err != nil {
		return
	}

	if md.Version != version {
		m.log.Warning("buildpack version changed from %s to %s", md.Version, version)
	}
}

func (m *Manifest) StoreBuildpackMetadata(cacheDir string) error {
	version, err := m.Version()
	if err != nil {
		return err
	}

	md := BuildpackMetadata{Language: m.Language(), Version: version}

	if exists, err := FileExists(cacheDir); err != nil {
		return err
	} else if !exists {
		return nil
	}

	y := &YAML{}
	return y.Write(filepath.Join(cacheDir, "BUILDPACK_METADATA"), &md)
}

func (m *Manifest) Language() string {
	return m.LanguageString
}

func (m *Manifest) Version() (string, error) {
	version, err := ioutil.ReadFile(filepath.Join(m.manifestRootDir, "VERSION"))
	if err != nil {
		return "", fmt.Errorf("unable to read VERSION file %s", err)
	}

	return strings.TrimSpace(string(version)), nil
}

func (m *Manifest) CheckStackSupport() error {
	requiredStack := os.Getenv("CF_STACK")

	if requiredStack == CFLINUXFS2 {
		m.log.Warning("\n" + ATTENTION_MSG + "\n" + WARNING_MSG_CFLINUXFS2 + "\n" + ATTENTION_MSG)
	}

	if requiredStack == WINDOWS2016 {
		m.log.Warning("\n" + ATTENTION_MSG + "\n" + WARNING_MSG_WINDOWS2016 + "\n" + ATTENTION_MSG)
	}

	if m.manifestSupportsStack(requiredStack) {
		return nil
	}

	return fmt.Errorf("required stack %s was not found", requiredStack)
}

func (m *Manifest) manifestSupportsStack(stack string) bool {
	if m.Stack != "" {
		return m.Stack == stack
	}

	if len(m.ManifestEntries) == 0 {
		return true
	}

	for _, entry := range m.ManifestEntries {
		if m.entrySupportsStack(&entry, stack) {
			return true
		}
	}

	return false
}

func (m *Manifest) DefaultVersion(depName string) (Dependency, error) {
	var defaultVersion string
	var err error
	numDefaults := 0

	for _, defaultDep := range m.DefaultVersions {
		if depName == defaultDep.Name {
			defaultVersion = defaultDep.Version
			numDefaults++
		}
	}

	if numDefaults == 0 {
		err = fmt.Errorf("no default version for %s", depName)
	} else if numDefaults > 1 {
		err = fmt.Errorf("found %d default versions for %s", numDefaults, depName)
	}

	if err != nil {
		m.log.Error(defaultVersionsError)
		return Dependency{}, err
	}

	depVersions := m.AllDependencyVersions(depName)
	highestVersion, err := FindMatchingVersion(defaultVersion, depVersions)

	if err != nil {
		m.log.Error(defaultVersionsError)
		return Dependency{}, err
	}

	return Dependency{Name: depName, Version: highestVersion}, nil
}

func fetchCachedBuildpackDependency(entry *ManifestEntry, outputFile, manifestRootDir string, manifestLog *Logger) error {
	source := entry.File
	if !filepath.IsAbs(source) {
		source = filepath.Join(manifestRootDir, source)
	}
	manifestLog.Info("Copy [%s]", source)
	if err := CopyFile(source, outputFile); err != nil {
		return err
	}
	return deleteBadFile(entry, outputFile)
}

func deleteBadFile(entry *ManifestEntry, outputFile string) error {
	if err := CheckSha256(outputFile, entry.SHA256); err != nil {
		os.Remove(outputFile)
		return err
	}
	return nil
}

func downloadDependency(entry *ManifestEntry, outputFile string, logger *Logger, retryTimeLimit time.Duration, retryTimeInitialInterval time.Duration) error {
	filteredURI, err := filterURI(entry.URI)
	if err != nil {
		return err
	}
	logger.Info("Download [%s]", filteredURI)
	err = downloadFile(entry.URI, outputFile, retryTimeLimit, retryTimeInitialInterval, logger)
	if err != nil {
		return err
	}

	return deleteBadFile(entry, outputFile)
}

func (m *Manifest) entrySupportsStack(entry *ManifestEntry, stack string) bool {

	if m.Stack != "" {
		return m.Stack == stack
	}

	for _, s := range entry.CFStacks {
		if s == stack {
			return true
		}
	}

	return false
}

func (m *Manifest) AllDependencyVersions(depName string) []string {
	var depVersions []string
	currentStack := os.Getenv("CF_STACK")

	for _, e := range m.ManifestEntries {
		if e.Dependency.Name == depName && m.entrySupportsStack(&e, currentStack) {
			depVersions = append(depVersions, e.Dependency.Version)
		}
	}

	return depVersions
}

func (m *Manifest) GetEntry(dep Dependency) (*ManifestEntry, error) {
	currentStack := os.Getenv("CF_STACK")

	for _, e := range m.ManifestEntries {
		if e.Dependency == dep && m.entrySupportsStack(&e, currentStack) {
			return &e, nil
		}
	}

	m.log.Error(dependencyMissingError(m, dep))
	return nil, fmt.Errorf("dependency %s %s not found", dep.Name, dep.Version)
}

func (m *Manifest) IsCached() bool {
	dependenciesDir := filepath.Join(m.manifestRootDir, "dependencies")

	isCached, err := FileExists(dependenciesDir)
	if err != nil {
		m.log.Warning("Error determining if buildpack is cached: %s", err)
	}

	return isCached
}
