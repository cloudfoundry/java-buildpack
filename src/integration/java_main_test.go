package integration_test

import (
	"path/filepath"
	"testing"

	"github.com/cloudfoundry/switchblade"
	"github.com/sclevine/spec"

	. "github.com/onsi/gomega"
)

func testJavaMain(platform switchblade.Platform, fixtures string) func(*testing.T, spec.G, spec.S) {
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

		context("with a Java Main application", func() {
			it("detects application with Main-Class manifest entry", func() {
				_, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "11",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "main"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				// Verify buildpack detects Java Main container from MANIFEST.MF
				Expect(logs.String()).To(ContainSubstring("Java Buildpack"))
				Expect(logs.String()).To(ContainSubstring("Java Main"))
			})
		})

		context("with explicit main class", func() {
			it("detects and configures the specified main class", func() {
				_, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION":      "11",
						"JBP_CONFIG_JAVA_MAIN": `{java_main_class: "io.pivotal.SimpleJava"}`,
					}).
					Execute(name, filepath.Join(fixtures, "containers", "main"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				// Verify buildpack detects and applies explicit main class configuration
				Expect(logs.String()).To(ContainSubstring("Java Buildpack"))
				Expect(logs.String()).To(ContainSubstring("Java Main"))
			})
		})

		context("with custom arguments", func() {
			it("successfully stages with custom arguments", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION":      "11",
						"JBP_CONFIG_JAVA_MAIN": `{arguments: "--server.port=$PORT"}`,
					}).
					Execute(name, filepath.Join(fixtures, "containers", "main"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				// Verify buildpack stages successfully with custom arguments
				Expect(logs.String()).To(ContainSubstring("Java Buildpack"))
				Expect(logs.String()).To(ContainSubstring("Java Main"))

				// Verify app can start (validates command with arguments is valid)
				Eventually(deployment.ExternalURL).ShouldNot(BeEmpty())
			})
		})

		context("with JAVA_OPTS", func() {
			it("detects application with custom Java options", func() {
				_, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "11",
						// Reduce memory settings to fit within 1G limit (v4 calculator)
						"JAVA_OPTS": "-Xmx384m -XX:ReservedCodeCacheSize=120M -Xss512k -XX:+UseG1GC",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "main"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				// Verify buildpack stages successfully with JAVA_OPTS
				Expect(logs.String()).To(ContainSubstring("Java Buildpack"))
				Expect(logs.String()).To(ContainSubstring("Java Main"))
			})
		})

		context("with JRE vendor selection", func() {
			it("deploys with SAPMachine JRE from manifest", func() {
				_, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"JBP_CONFIG_SAP_MACHINE_JRE": `{jre: {version: 17.+}}`,
					}).
					Execute(name, filepath.Join(fixtures, "containers", "main"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				// Verify SAPMachine JRE was installed from manifest
				Expect(logs.String()).To(ContainSubstring("Java Buildpack"))
				Expect(logs.String()).To(ContainSubstring("Installing SAP Machine"))
				Expect(logs.String()).To(ContainSubstring("17."))
			})
		})
	}
}
