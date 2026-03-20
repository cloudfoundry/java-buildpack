package integration_test

import (
	"path/filepath"
	"testing"

	"github.com/cloudfoundry/switchblade"
	"github.com/sclevine/spec"

	"github.com/cloudfoundry/switchblade/matchers"
	. "github.com/onsi/gomega"
)

func testSpringBootCLI(platform switchblade.Platform, fixtures string) func(*testing.T, spec.G, spec.S) {
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

		context("with a Spring Boot CLI application", func() {
			it("successfully deploys a valid Spring Boot CLI app", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "11",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "spring_boot_cli_valid_app"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				Expect(logs.String()).To(ContainSubstring("Java Buildpack"))
				Eventually(deployment).Should(matchers.Serve(Not(BeEmpty())))
			})

			it("successfully deploys with beans configuration", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "11",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "spring_boot_cli_beans_configuration"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				Expect(logs.String()).To(ContainSubstring("Java Buildpack"))
				Eventually(deployment).Should(matchers.Serve(Not(BeEmpty())))
			})

			it("successfully deploys non-POGO Groovy scripts", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "11",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "spring_boot_cli_non_pogo"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				Expect(logs.String()).To(ContainSubstring("Java Buildpack"))
				Eventually(deployment).Should(matchers.Serve(Not(BeEmpty())))
			})

			it("successfully deploys with main method", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "11",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "spring_boot_cli_main_method"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				Expect(logs.String()).To(ContainSubstring("Java Buildpack"))
				Eventually(deployment).Should(matchers.Serve(Not(BeEmpty())))
			})

			it("successfully deploys Groovy with WEB-INF", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "11",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "spring_boot_cli_groovy_with_web_inf"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				Expect(logs.String()).To(ContainSubstring("Java Buildpack"))
				Eventually(deployment).Should(matchers.Serve(Not(BeEmpty())))
			})
		})

		context("with JRE version selection", func() {
			it("deploys Spring Boot CLI with Java 17", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "17",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "spring_boot_cli_valid_app"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				Expect(logs.String()).To(ContainSubstring("Java Buildpack"))
				Expect(logs.String()).To(ContainSubstring("Installing OpenJDK 17."))
				Eventually(deployment).Should(matchers.Serve(Not(BeEmpty())))
			})
		})
	}
}
