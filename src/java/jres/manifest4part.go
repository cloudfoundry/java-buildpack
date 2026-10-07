package jres

import (
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/libbuildpack"
)

func Build4PartMap(manifest *libbuildpack.Manifest, depNames ...string) map[string]libbuildpack.ManifestEntry {
	nameSet := make(map[string]bool, len(depNames))
	for _, n := range depNames {
		nameSet[n] = true
	}
	result := make(map[string]libbuildpack.ManifestEntry)
	for _, entry := range manifest.ManifestEntries {
		if nameSet[entry.Dependency.Name] && isValidVersion4Part(entry.Dependency.Version) {
			result[entry.Dependency.Version] = entry
		}
	}
	return result
}

type FilteredManifest struct {
	real      *libbuildpack.Manifest
	skipNames map[string]bool
}

func NewFilteredManifest(manifest *libbuildpack.Manifest, depNames ...string) common.Manifest {
	skip := make(map[string]bool, len(depNames))
	for _, n := range depNames {
		skip[n] = true
	}
	return &FilteredManifest{real: manifest, skipNames: skip}
}

func (f *FilteredManifest) AllDependencyVersions(depName string) []string {
	all := f.real.AllDependencyVersions(depName)
	if !f.skipNames[depName] {
		return all
	}
	filtered := all[:0:0]
	for _, v := range all {
		if !isValidVersion4Part(v) {
			filtered = append(filtered, v)
		}
	}
	return filtered
}

func (f *FilteredManifest) DefaultVersion(depName string) (libbuildpack.Dependency, error) {
	if f.skipNames[depName] {
		saved := f.real.ManifestEntries
		kept := saved[:0:0]
		for _, e := range saved {
			if !(e.Dependency.Name == depName && isValidVersion4Part(e.Dependency.Version)) {
				kept = append(kept, e)
			}
		}
		f.real.ManifestEntries = kept
		dep, err := f.real.DefaultVersion(depName)
		f.real.ManifestEntries = saved
		return dep, err
	}
	return f.real.DefaultVersion(depName)
}

func (f *FilteredManifest) GetEntry(dep libbuildpack.Dependency) (*libbuildpack.ManifestEntry, error) {
	return f.real.GetEntry(dep)
}
