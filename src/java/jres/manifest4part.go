package jres

import "github.com/cloudfoundry/libbuildpack"

// Extract4PartEntries removes all 4-digit-version entries for the given
// dependency names from the concrete manifest and returns them in a map
// keyed by version string.  Callers must invoke this before passing the
// manifest to libbuildpack.NewInstaller, because neither blang/semver nor
// Masterminds/semver can parse a 4-part version string; leaving such entries
// in the manifest breaks AllDependencyVersions, DefaultVersion, and
// warnNewerPatch for every dependency that shares the version list.
func Extract4PartEntries(manifest *libbuildpack.Manifest, depNames ...string) map[string]libbuildpack.ManifestEntry {
	nameSet := make(map[string]bool, len(depNames))
	for _, n := range depNames {
		nameSet[n] = true
	}

	extracted := make(map[string]libbuildpack.ManifestEntry)
	kept := manifest.ManifestEntries[:0]

	for _, entry := range manifest.ManifestEntries {
		if nameSet[entry.Dependency.Name] && isValidVersion4Part(entry.Dependency.Version) {
			extracted[entry.Dependency.Version] = entry
		} else {
			kept = append(kept, entry)
		}
	}

	manifest.ManifestEntries = kept
	return extracted
}
