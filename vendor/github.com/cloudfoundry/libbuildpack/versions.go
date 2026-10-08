package libbuildpack

import (
	"fmt"
	"sort"
	"strconv"
	"strings"

	semver2 "github.com/Masterminds/semver"
	semver1 "github.com/blang/semver"
)

type versionWithOriginal struct {
	original string
	version  semver1.Version
	build    int // 4th version segment, -1 if absent
}
type versionsWithOriginal []versionWithOriginal

func (v versionsWithOriginal) Len() int      { return len(v) }
func (v versionsWithOriginal) Swap(i, j int) { v[i], v[j] = v[j], v[i] }
func (v versionsWithOriginal) Less(i, j int) bool {
	if v[i].version.EQ(v[j].version) {
		return v[i].build < v[j].build
	}
	return v[i].version.LT(v[j].version)
}

// normalizeSemver truncates a purely numeric 4-part version string (e.g. "21.0.12.1")
// to its first three segments ("21.0.12") so that standard semver libraries can parse
// it. The original string is preserved separately for output.
// Strings with pre-release identifiers or build metadata (e.g. "8.0.100-preview.7.23376.3")
// are returned unchanged — only strings matching \d+\.\d+\.\d+\.\d+ are truncated.
// Note: if multiple 4-part versions share the same 3-part prefix (e.g. "17.0.20.1"
// and "17.0.20.2"), the 4th segment is used as a numeric tie-breaker during sorting.
// In practice only one 4-part patch release per major version line is expected in
// the manifest at any time.
func normalizeSemver(ver string) string {
	if is4PartVersion(ver) {
		parts := strings.SplitN(ver, ".", 5)
		return strings.Join(parts[:3], ".")
	}
	return ver
}

// parseBuildSegment extracts the 4th numeric segment from a version string.
// Returns -1 if the string has 3 or fewer segments (absent), or the numeric
// value of the 4th segment if present. This distinguishes "21.0.12" (returns -1)
// from "21.0.12.0" (returns 0) so that 4-part versions always sort after their
// 3-part prefix regardless of the 4th segment value.
// Only purely numeric 4-part versions are considered; all others return -1.
func parseBuildSegment(ver string) int {
	if !is4PartVersion(ver) {
		return -1
	}
	parts := strings.SplitN(ver, ".", 5)
	n, err := strconv.Atoi(parts[3])
	if err != nil {
		return -1
	}
	return n
}

// is4PartVersion reports whether ver is exactly a 4-part numeric version string.
// Each segment must contain only ASCII digits — leading signs are rejected.
func is4PartVersion(ver string) bool {
	parts := strings.Split(ver, ".")
	if len(parts) != 4 {
		return false
	}
	for _, p := range parts {
		if p == "" {
			return false
		}
		for _, r := range p {
			if r < '0' || r > '9' {
				return false
			}
		}
	}
	return true
}

func FindMatchingVersion(constraint string, versions []string) (string, error) {
	vs, err := FindMatchingVersions(constraint, versions)
	if err != nil {
		return "", err
	}
	return vs[len(vs)-1], nil
}

func FindMatchingVersions(constraint string, versions []string) ([]string, error) {
	// Short-circuit: exact 4-part version constraint — use string equality rather
	// than semver parsing, since neither blang/semver nor Masterminds/semver accept
	// a 4-part string as a constraint.
	if is4PartVersion(constraint) {
		for _, v := range versions {
			if v == constraint {
				return []string{v}, nil
			}
		}
		return []string{}, fmt.Errorf("no match found for %s in %v", constraint, versions)
	}

	matchedVersions, err := matchSemver1(constraint, versions)
	if err == nil {
		return matchedVersions, nil
	}

	return matchSemver2(constraint, versions)
}

func matchSemver1(constraint string, versions []string) ([]string, error) {
	var depVersions versionsWithOriginal
	versionConstraint, err := semver1.ParseRange(constraint)
	if err != nil {
		return []string{}, err
	}

	for _, ver := range versions {
		depVersion, err := semver1.Parse(normalizeSemver(ver))
		if err != nil {
			return []string{}, err
		}

		if versionConstraint(depVersion) {
			depVersions = append(depVersions, versionWithOriginal{
				original: ver,
				version:  depVersion,
				build:    parseBuildSegment(ver),
			})
		}
	}

	if len(depVersions) != 0 {
		sort.Sort(depVersions)
		var vs []string
		for _, depV := range depVersions {
			vs = append(vs, depV.original)
		}
		return vs, nil
	}

	return []string{}, fmt.Errorf("no match found for %s in %v", constraint, versions)
}

func matchSemver2(constraint string, versions []string) ([]string, error) {
	type versionEntry struct {
		original string
		parsed   *semver2.Version
		build    int
	}
	var depVersions []versionEntry
	versionConstraint, err := semver2.NewConstraint(constraint)
	if err != nil {
		return []string{}, err
	}

	for _, ver := range versions {
		depVersion, err := semver2.NewVersion(normalizeSemver(ver))
		if err != nil {
			return []string{}, err
		}

		if versionConstraint.Check(depVersion) {
			depVersions = append(depVersions, versionEntry{
				original: ver,
				parsed:   depVersion,
				build:    parseBuildSegment(ver),
			})
		}
	}

	if len(depVersions) != 0 {
		sort.Slice(depVersions, func(i, j int) bool {
			if depVersions[i].parsed.Equal(depVersions[j].parsed) {
				return depVersions[i].build < depVersions[j].build
			}
			return depVersions[i].parsed.LessThan(depVersions[j].parsed)
		})
		var vs []string
		for _, e := range depVersions {
			vs = append(vs, e.original)
		}
		return vs, nil
	}

	return []string{}, fmt.Errorf("no match found for %s in %v", constraint, versions)
}
