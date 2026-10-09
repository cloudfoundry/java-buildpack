package libbuildpack

import (
	"fmt"
	"regexp"
	"sort"
	"strconv"
	"strings"

	semver2 "github.com/Masterminds/semver"
	semver1 "github.com/blang/semver"
)

type versionWithOriginal struct {
	original string
	version  semver1.Version
}
type versionsWithOriginal []versionWithOriginal

func (v versionsWithOriginal) Len() int      { return len(v) }
func (v versionsWithOriginal) Swap(i, j int) { v[i], v[j] = v[j], v[i] }
func (v versionsWithOriginal) Less(i, j int) bool {
	if v[i].version.EQ(v[j].version) {
		return compareJEP322(v[i].original, v[j].original) < 0
	}
	return v[i].version.LT(v[j].version)
}

// jep322Regex matches numeric JEP 322 style versions: any number of numeric
// fields, optionally followed by a numeric build number, e.g. "21", "21.0.12",
// "21.0.12.1", "21.0.10.0.1", "21.0.12+10" or "21.0.12.1+1".
// See https://openjdk.org/jeps/322.
var jep322Regex = regexp.MustCompile(`^(\d+(?:\.\d+)*)(?:\+(\d+))?$`)

type jep322Version struct {
	fields []int
	build  int // -1 if absent
}

// parseJEP322 parses a numeric JEP 322 style version. It returns false for
// anything else, e.g. versions with pre-release identifiers or non-numeric
// build metadata, which are left to the semver libraries.
func parseJEP322(ver string) (jep322Version, bool) {
	m := jep322Regex.FindStringSubmatch(ver)
	if m == nil {
		return jep322Version{}, false
	}
	parts := strings.Split(m[1], ".")
	v := jep322Version{fields: make([]int, len(parts)), build: -1}
	for i, p := range parts {
		n, err := strconv.Atoi(p)
		if err != nil {
			return jep322Version{}, false
		}
		v.fields[i] = n
	}
	if m[2] != "" {
		n, err := strconv.Atoi(m[2])
		if err != nil {
			return jep322Version{}, false
		}
		v.build = n
	}
	return v, true
}

// compareFields compares numeric fields, treating missing fields as zero,
// so "21.0.12" and "21.0.12.0" compare equal.
func (a jep322Version) compareFields(b jep322Version) int {
	for i := 0; i < len(a.fields) || i < len(b.fields); i++ {
		var x, y int
		if i < len(a.fields) {
			x = a.fields[i]
		}
		if i < len(b.fields) {
			y = b.fields[i]
		}
		if x != y {
			if x < y {
				return -1
			}
			return 1
		}
	}
	return 0
}

// compareJEP322 orders two version strings by all numeric fields (trailing
// zeros insignificant), then by numeric build number (absent < +1 < +2), and
// finally by number of fields so that ordering stays deterministic
// ("21.0.12" < "21.0.12.0"). Returns 0 if either version is not a numeric
// JEP 322 version.
func compareJEP322(a, b string) int {
	va, okA := parseJEP322(a)
	vb, okB := parseJEP322(b)
	if !okA || !okB {
		return 0
	}
	if c := va.compareFields(vb); c != 0 {
		return c
	}
	if va.build != vb.build {
		if va.build < vb.build {
			return -1
		}
		return 1
	}
	return len(va.fields) - len(vb.fields)
}

// normalizeSemver truncates a numeric JEP 322 version with more than three
// fields (e.g. "21.0.12.1", "21.0.12.1+1" or "21.0.10.0.1") to its first three
// fields ("21.0.12") so that the semver libraries can parse it. The original
// string is preserved separately for output and ordering (see compareJEP322).
// All other strings, including 3-part versions with build metadata
// ("21.0.12+10") and pre-release versions ("8.0.100-preview.7.23376.3"), are
// returned unchanged.
func normalizeSemver(ver string) string {
	if v, ok := parseJEP322(ver); ok && len(v.fields) > 3 {
		return fmt.Sprintf("%d.%d.%d", v.fields[0], v.fields[1], v.fields[2])
	}
	return ver
}

// isExactJEP322Constraint reports whether constraint is an exact numeric
// version that the semver libraries cannot handle correctly as a constraint:
// more than three fields ("21.0.12.1") or an explicit build number
// ("21.0.12+10", "21.0.12.1+1").
func isExactJEP322Constraint(constraint string) (jep322Version, bool) {
	v, ok := parseJEP322(constraint)
	if !ok || (len(v.fields) <= 3 && v.build < 0) {
		return jep322Version{}, false
	}
	return v, true
}

// matchExactJEP322 returns all versions equal to the constraint. Without a
// build number in the constraint any build matches ("21.0.12.1" matches
// "21.0.12.1+1" and "21.0.12.1+2"); with one, the build must be equal.
func matchExactJEP322(constraint string, c jep322Version, versions []string) ([]string, error) {
	var matched []string
	for _, ver := range versions {
		v, ok := parseJEP322(ver)
		if !ok || v.compareFields(c) != 0 {
			continue
		}
		if c.build >= 0 && v.build != c.build {
			continue
		}
		matched = append(matched, ver)
	}
	if len(matched) == 0 {
		return []string{}, fmt.Errorf("no match found for %s in %v", constraint, versions)
	}
	sort.SliceStable(matched, func(i, j int) bool {
		return compareJEP322(matched[i], matched[j]) < 0
	})
	return matched, nil
}

func FindMatchingVersion(constraint string, versions []string) (string, error) {
	vs, err := FindMatchingVersions(constraint, versions)
	if err != nil {
		return "", err
	}
	return vs[len(vs)-1], nil
}

func FindMatchingVersions(constraint string, versions []string) ([]string, error) {
	// Short-circuit: exact JEP 322 version constraint. Neither blang/semver nor
	// Masterminds/semver accept more than three fields, and both ignore build
	// metadata when comparing.
	if c, ok := isExactJEP322Constraint(constraint); ok {
		return matchExactJEP322(constraint, c, versions)
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
			})
		}
	}

	if len(depVersions) != 0 {
		sort.Slice(depVersions, func(i, j int) bool {
			if depVersions[i].parsed.Equal(depVersions[j].parsed) {
				return compareJEP322(depVersions[i].original, depVersions[j].original) < 0
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
