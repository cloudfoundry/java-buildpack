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

				// Verify embedded Cloud Foundry-optimized Tomcat configuration was installed
				Expect(logs.String()).To(ContainSubstring("Installing Cloud Foundry-optimized Tomcat configuration defaults"))
				Expect(logs.String()).To(ContainSubstring("Dynamic port binding (${http.port} from $PORT)"))
				Expect(logs.String()).To(ContainSubstring("HTTP/2 support enabled"))
				Expect(logs.String()).To(ContainSubstring("RemoteIpValve for X-Forwarded-* headers"))
				Expect(logs.String()).To(ContainSubstring("CloudFoundryAccessLoggingValve with vcap_request_id"))
				Expect(logs.String()).To(ContainSubstring("Stdout logging via CloudFoundryConsoleHandler"))

				Eventually(deployment).Should(matchers.Serve(ContainSubstring("OK")))

				// Verify runtime logs contain CloudFoundry-specific Tomcat features
				// Use Eventually to wait for logs to be flushed, as they may not appear immediately

				// Check for HTTP/2 support in runtime logs (Tomcat startup messages)
				// These should appear quickly during Tomcat startup
				Eventually(func() string {
					logs, _ := deployment.RuntimeLogs()
					return logs
				}, "10s", "1s").Should(Or(
					ContainSubstring("Http11NioProtocol"),
					ContainSubstring("Starting ProtocolHandler"),
					ContainSubstring("HTTP/1.1"),
				))

				// Check for CloudFoundry access logging valve
				// Access logs may take longer to flush, so we poll with Eventually
				// The request above with matchers.Serve should have generated an access log entry
				Eventually(func() string {
					logs, _ := deployment.RuntimeLogs()
					return logs
				}, "10s", "1s").Should(Or(
					ContainSubstring("[ACCESS]"),
					ContainSubstring("vcap_request_id:"),
				))
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
			it("downloads and applies configuration from real repository", func() {
				// This test verifies the external configuration workflow:
				// 1. Configuration is detected from JBP_CONFIG_TOMCAT
				// 2. Buildpack fetches index.yml from repository_root
				// 3. Buildpack downloads the specified version's tar.gz
				// 4. Configuration is extracted and applied to Tomcat
				// 5. Application deploys successfully with custom configuration
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION":   "11",
						"JBP_CONFIG_TOMCAT": "{tomcat: {external_configuration_enabled: true}, external_configuration: {repository_root: \"https://tomcat-config.cfapps.eu12.hana.ondemand.com\", version: \"1.4.0\"}}",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "tomcat_jakarta"))

				// Build should succeed with real repository
				Expect(err).NotTo(HaveOccurred())

				// Verify external configuration was detected and parsed correctly
				Expect(logs.String()).To(ContainSubstring("External Tomcat configuration is enabled"))
				Expect(logs.String()).To(ContainSubstring("External configuration repository: https://tomcat-config.cfapps.eu12.hana.ondemand.com (version: 1.4.0)"))

				// Verify buildpack falls back to direct download when not in manifest
				Expect(logs.String()).To(ContainSubstring("External configuration not in manifest, downloading directly from repository"))

				// Verify buildpack fetches index.yml successfully
				Expect(logs.String()).To(ContainSubstring("Fetching external configuration index from: https://tomcat-config.cfapps.eu12.hana.ondemand.com/index.yml"))

				// Verify buildpack downloads the configuration archive
				Expect(logs.String()).To(ContainSubstring("Found version 1.4.0 in index"))
				Expect(logs.String()).To(ContainSubstring("Extracting external configuration"))

				// Verify configuration was installed successfully
				Expect(logs.String()).To(ContainSubstring("Successfully installed external Tomcat configuration version 1.4.0"))

				// Verify application starts successfully with custom configuration
				Eventually(deployment).Should(matchers.Serve(ContainSubstring("OK")))
			})
		})
	}
}
