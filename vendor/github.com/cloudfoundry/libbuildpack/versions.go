package libbuildpack

import (
	"fmt"
	"sort"

	semver2 "github.com/Masterminds/semver"
	semver1 "github.com/blang/semver"
)

type versionWithOriginal struct {
	original string
	version  semver1.Version
}
type versionsWithOriginal []versionWithOriginal

func (v versionsWithOriginal) Len() int           { return len(v) }
func (v versionsWithOriginal) Swap(i, j int)      { v[i], v[j] = v[j], v[i] }
func (v versionsWithOriginal) Less(i, j int) bool { return v[i].version.LT(v[j].version) }

func FindMatchingVersion(constraint string, versions []string) (string, error) {
	vs, err := FindMatchingVersions(constraint, versions)
	if err != nil {
		return "", err
	}
	return vs[len(vs)-1], nil
}

func FindMatchingVersions(constraint string, versions []string) ([]string, error) {
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
		depVersion, err := semver1.Parse(ver)
		if err != nil {
			return []string{}, err
		}
		versionWithOriginal := versionWithOriginal{
			original: ver,
			version:  depVersion,
		}

		if versionConstraint(depVersion) {
			depVersions = append(depVersions, versionWithOriginal)
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
	var depVersions []*semver2.Version
	versionConstraint, err := semver2.NewConstraint(constraint)
	if err != nil {
		return []string{}, err
	}

	for _, ver := range versions {
		depVersion, err := semver2.NewVersion(ver)
		if err != nil {
			return []string{}, err
		}

		if versionConstraint.Check(depVersion) {
			depVersions = append(depVersions, depVersion)
		}
	}

	if len(depVersions) != 0 {
		sort.Sort(semver2.Collection(depVersions))
		var vs []string
		for _, depV := range depVersions {
			vs = append(vs, depV.Original())
		}
		return vs, nil
	}

	return []string{}, fmt.Errorf("no match found for %s in %v", constraint, versions)
}
