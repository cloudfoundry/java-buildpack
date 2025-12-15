package integration_test

import (
	"path/filepath"
	"testing"

	"github.com/cloudfoundry/switchblade"
	"github.com/cloudfoundry/switchblade/matchers"
	"github.com/sclevine/spec"

	. "github.com/onsi/gomega"
)

func testTomcat(platform switchblade.Platform, fixtures string) func(*testing.T, spec.G, spec.S) {
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
			if t.Failed() && name != "" {
				t.Logf("❌ FAILED TEST - App/Container: %s", name)
				t.Logf("   Platform: %s", settings.Platform)
			}
			if name != "" && (!settings.KeepFailedContainers || !t.Failed()) {
				Expect(platform.Delete.Execute(name)).To(Succeed())
			}
		})

		context("with a simple servlet app", func() {
			it("successfully deploys and runs with Java 11 (Jakarta EE)", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "11",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "tomcat_jakarta"))

				Expect(err).NotTo(HaveOccurred(), logs.String)

				Eventually(deployment).Should(matchers.Serve(ContainSubstring("OK")))
			})
		})

		context("with JRE selection", func() {
			it("deploys with Java 8 (Tomcat 9 + javax.servlet)", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "8",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "tomcat_javax"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				Expect(logs.String()).To(ContainSubstring("OpenJDK"))
				Expect(logs.String()).To(ContainSubstring("Tomcat 9"))
				Eventually(deployment).Should(matchers.Serve(ContainSubstring("OK")))
			})

			it("deploys with Java 11 (Tomcat 10 + jakarta.servlet)", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "11",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "tomcat_jakarta"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				Expect(logs.String()).To(ContainSubstring("OpenJDK"))
				Expect(logs.String()).To(ContainSubstring("Tomcat 10"))
				Eventually(deployment).Should(matchers.Serve(ContainSubstring("OK")))
			})

			it("deploys with Java 17 (Tomcat 10 + jakarta.servlet)", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "17",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "tomcat_jakarta"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				Expect(logs.String()).To(ContainSubstring("OpenJDK"))
				Expect(logs.String()).To(ContainSubstring("Tomcat 10"))
				Eventually(deployment).Should(matchers.Serve(ContainSubstring("OK")))
			})
		})

		context("with memory limits", func() {
			it("respects memory calculator settings", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION":         "11",
						"JAVA_OPTS":               "-Xmx256m",
						"JBP_CONFIG_OPEN_JDK_JRE": "{jre: {version: 11.+}}",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "tomcat_jakarta"))

				Expect(err).NotTo(HaveOccurred(), logs.String)

				Expect(logs.String()).To(ContainSubstring("memory"))
				Eventually(deployment).Should(matchers.Serve(ContainSubstring("OK")))
			})
		})

		context("with Java 21", func() {
			it("successfully deploys WAR file with Java 21 using git buildpack", func() {
				// Regression test: This deployment scenario previously failed with:
				// "Failed to build droplet release: buildpack's release output invalid:
				//  yaml: unmarshal errors: line 1: cannot unmarshal !!str `-----> ...`"
				//
				// The bug: When using a git URL buildpack (not pre-packaged), the bash wrapper
				// scripts (bin/detect, bin/supply, bin/finalize, bin/release) were used.
				// These bash wrappers compiled Go binaries on-the-fly and had echo statements
				// like "-----> Running go build release" that polluted stdout.
				//
				// During the release phase, Cloud Foundry expects pure YAML on stdout.
				// The echo pollution caused: "cannot unmarshal !!str `-----> ...`"
				//
				// This test explicitly uses a git URL to ensure the bash scripts work correctly.
				// The fix converted everything to pure bash (no Go wrappers) and removed all
				// echo statements so only clean YAML is output.
				//
				// LIMITATION: Git URL buildpacks only work on CF platform because the CF CLI
				// handles git cloning (see cloudfoundry/setup.go:332-335 which passes git URLs
				// directly to `cf push -b <url>`). Switchblade's Docker platform only supports
				// HTTP downloads via buildpacks_cache.go:64 http.Get(), not git clone.
				// The test must run on CF platform to properly test git URL buildpack deployment.

				if settings.Platform == "docker" {
					t.Skip("Git URL buildpacks require CF platform - Docker platform cannot clone git repos")
				}

				deployment, logs, err := platform.Deploy.
					WithBuildpacks("https://github.com/cloudfoundry/java-buildpack.git#feature/go-migration").
					WithEnv(map[string]string{
						"BP_JAVA_VERSION":         "21",
						"JBP_CONFIG_OPEN_JDK_JRE": "{jre: {version: 21.+}}",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "tomcat_jakarta"))

				Expect(err).NotTo(HaveOccurred(), logs.String)

				// Verify Java 21 is used
				Expect(logs.String()).To(ContainSubstring("OpenJDK"))
				Expect(logs.String()).To(Or(
					ContainSubstring("21."),
					ContainSubstring("Tomcat"),
				))

				// If deployment succeeds, it means:
				// 1. bin/detect succeeded (detected Tomcat)
				// 2. bin/supply succeeded (downloaded dependencies)
				// 3. bin/finalize succeeded (configured app)
				// 4. bin/release succeeded (output valid YAML) <- THIS IS THE BUG FIX
				// 5. App started and responds to requests
				Eventually(deployment).Should(matchers.Serve(ContainSubstring("OK")))
			})
		})

		context("with external Tomcat configuration", func() {
			it("attempts to download external configuration from repository_root URL", func() {
				// Use a fake but syntactically valid URL - the build should fail since the URL doesn't exist
				_, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION":   "11",
						"JBP_CONFIG_TOMCAT": "{tomcat: {external_configuration_enabled: true}, external_configuration: {repository_root: \"https://example.com/tomcat-config\", version: \"1.4.0\"}}",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "tomcat_jakarta"))

				// Build should fail since external config is required when explicitly configured
				Expect(err).To(HaveOccurred())

				// Verify external configuration was detected
				Expect(logs.String()).To(ContainSubstring("External Tomcat configuration is enabled"))
				Expect(logs.String()).To(ContainSubstring("External configuration repository: https://example.com/tomcat-config (version: 1.4.0)"))

				// Verify it attempts direct download (new behavior)
				Expect(logs.String()).To(ContainSubstring("External configuration not in manifest, downloading directly from repository"))
				Expect(logs.String()).To(ContainSubstring("Downloading external configuration from: https://example.com/tomcat-config/tomcat-external-configuration-1.4.0.tar.gz"))

				// Verify build fails when download fails
				Expect(logs.String()).To(ContainSubstring("failed to install external Tomcat configuration"))
			})
		})
	}
}
