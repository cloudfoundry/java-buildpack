package integration_test

import (
	"testing"

	"github.com/cloudfoundry/switchblade"
	"github.com/cloudfoundry/switchblade/matchers"
	"github.com/sclevine/spec"

	. "github.com/onsi/gomega"
)

// testExecutableArchives deploys executable WAR/JAR fixtures from java-test-applications
// and verifies which container claims each of them.
func testExecutableArchives(platform switchblade.Platform, apps map[string]string) func(*testing.T, spec.G, spec.S) {
	return func(t *testing.T, context spec.G, it spec.S) {
		var (
			Expect     = NewWithT(t).Expect
			Eventually = NewWithT(t).Eventually
			name       string
		)

		it.Before(func() {
			if len(apps) == 0 {
				t.Skip("java-test-applications archives not downloaded (cached mode)")
			}

			var err error
			name, err = switchblade.RandomName()
			Expect(err).NotTo(HaveOccurred())
		})

		it.After(func() {
			cleanupDeployedApp(t, platform, name)
		})

		tests := []struct {
			description string
			artifact    string
			javaVersion string
			container   string
		}{
			{"Spring Boot 4 executable WAR", executableWarName, "21", "Spring Boot"},
			{"Spring Boot 3 executable WAR", executableWarBoot3Name, "17", "Spring Boot"},
			{"non-Boot WAR with a Main-Class manifest entry", mainClassWarName, "21", "Java Main"},
		}

		for _, tc := range tests {
			tc := tc
			context("with a "+tc.description, func() {
				it("is claimed by the "+tc.container+" container and serves requests", func() {
					deployment, logs, err := platform.Deploy.
						WithEnv(map[string]string{"BP_JAVA_VERSION": tc.javaVersion}).
						Execute(name, apps[tc.artifact])
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("Detected container: " + tc.container))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("ok")))
				})
			})
		}
	}
}
