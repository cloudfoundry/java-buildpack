package libbuildpack

import "fmt"

const defaultVersionsError = "The buildpack manifest is misconfigured for 'default_versions'. " +
	"Contact your Cloud Foundry operator/admin. For more information, see " +
	"https://docs.cloudfoundry.org/buildpacks/custom.html#specifying-default-versions"

func dependencyMissingError(m *Manifest, dep Dependency) string {
	var msg string
	otherVersions := m.AllDependencyVersions(dep.Name)

	msg += fmt.Sprintf("DEPENDENCY MISSING IN MANIFEST:\n\n")

	if otherVersions == nil {
		msg += fmt.Sprintf("Dependency %s is not provided by this buildpack\n", dep.Name)
	} else {
		msg += fmt.Sprintf("Version %s of dependency %s is not supported by this buildpack.\n", dep.Version, dep.Name)
		msg += fmt.Sprintf("The versions of %s supported in this buildpack are:\n", dep.Name)

		for _, ver := range otherVersions {
			msg += fmt.Sprintf("\t- %s\n", ver)
		}
	}

	return msg
}

func outdatedDependencyWarning(dep Dependency, newest string) string {
	warning := "A newer version of %s is available in this buildpack. " +
		"Please adjust your app to use version %s instead of version %s as soon as possible. " +
		"Old versions of %s are only provided to assist in migrating to newer versions."

	return fmt.Sprintf(warning, dep.Name, newest, dep.Version, dep.Name)
}

func endOfLifeWarning(depName, versionLine, eolDate, link string) string {
	warning := "%s %s will no longer be available in new buildpacks released after %s."
	if link != "" {
		warning += "\nSee: %s"
		return fmt.Sprintf(warning, depName, versionLine, eolDate, link)
	}

	return fmt.Sprintf(warning, depName, versionLine, eolDate)
}
