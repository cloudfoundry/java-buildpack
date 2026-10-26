package integration_test

import (
	"path/filepath"
	"testing"

	"github.com/cloudfoundry/switchblade"
	"github.com/cloudfoundry/switchblade/matchers"
	"github.com/sclevine/spec"

	. "github.com/onsi/gomega"
)

func testJREBlockedCerts(platform switchblade.Platform, fixtures string) func(*testing.T, spec.G, spec.S) {
	return func(t *testing.T, context spec.G, it spec.S) {
		var (
			Expect     = NewWithT(t).Expect
			Eventually = NewWithT(t).Eventually
			name       string
		)

		it.Before(func() {
			var err error
			name, err = switchblade.RandomName()
			Expect(err).NotTo(HaveOccurred())
		})

		it.After(func() {
			cleanupDeployedApp(t, platform, name)
		})

		it("ensures blocked.certs is up to date on Java 21", func() {
			deployment, logs, err := platform.Deploy.
				WithEnv(map[string]string{
					"BP_JAVA_VERSION": "21",
				}).
				Execute(name, filepath.Join(fixtures, "containers", "dist_zip"))
			Expect(err).NotTo(HaveOccurred(), logs.String)

			Expect(logs.String()).To(MatchRegexp(`(Added \d+ certificate\(s\) to blocked\.certs|blocked\.certs already contains all blocked certificates)`))
			Expect(logs.String()).To(MatchRegexp(`(Removed \d+ root certificate\(s\) from cacerts|cacerts already free of the removed root certificates)`))
			Eventually(deployment).Should(matchers.Serve(Not(BeEmpty())))
		})

		it("ensures blacklisted.certs is up to date on Java 8", func() {
			deployment, logs, err := platform.Deploy.
				WithEnv(map[string]string{
					"BP_JAVA_VERSION": "8",
				}).
				Execute(name, filepath.Join(fixtures, "containers", "dist_zip"))
			Expect(err).NotTo(HaveOccurred(), logs.String)

			Expect(logs.String()).To(MatchRegexp(`(Added \d+ certificate\(s\) to blacklisted\.certs|blacklisted\.certs already contains all blocked certificates)`))
			Expect(logs.String()).To(MatchRegexp(`(Removed \d+ root certificate\(s\) from cacerts|cacerts already free of the removed root certificates)`))
			Eventually(deployment).Should(matchers.Serve(Not(BeEmpty())))
		})

		it("does not add certificates when disabled", func() {
			deployment, logs, err := platform.Deploy.
				WithEnv(map[string]string{
					"BP_JAVA_VERSION":              "21",
					"JBP_CONFIG_JRE_BLOCKED_CERTS": "{enabled: false}",
					"JBP_CONFIG_JRE_REMOVED_ROOTS": "{enabled: false}",
				}).
				Execute(name, filepath.Join(fixtures, "containers", "dist_zip"))
			Expect(err).NotTo(HaveOccurred(), logs.String)

			Expect(logs.String()).NotTo(MatchRegexp(`certificate\(s\) to|already contains all blocked certificates|root certificate\(s\) from cacerts|already free of the removed`))
			Eventually(deployment).Should(matchers.Serve(Not(BeEmpty())))
		})
	}
}
