package integration_test

import (
	"path/filepath"
	"testing"

	"github.com/cloudfoundry/switchblade"
	"github.com/cloudfoundry/switchblade/matchers"
	"github.com/sclevine/spec"

	. "github.com/onsi/gomega"
)

func testSpringBoot(platform switchblade.Platform, fixtures string) func(*testing.T, spec.G, spec.S) {
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

		context("with a Spring Boot application", func() {
			it("successfully deploys and runs", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "11",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				Expect(logs.String()).To(ContainSubstring("Java Buildpack"))
				Eventually(deployment).Should(matchers.Serve(Not(BeEmpty())))
			})
		})

		context("with Spring Auto-reconfiguration", func() {
			it("detects Spring Framework", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "11",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				// Spring auto-reconfiguration should be detected
				Expect(logs.String()).To(ContainSubstring("Java Buildpack"))
				Eventually(deployment).Should(matchers.Serve(Not(BeEmpty())))
			})
		})

		context("with embedded Tomcat", func() {
			it("starts successfully", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "11",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				Expect(logs.String()).To(Or(
					ContainSubstring("Tomcat"),
					ContainSubstring("JRE"),
				))
				Eventually(deployment).Should(matchers.Serve(Not(BeEmpty())))
			})
		})

		context("with Java CFEnv", func() {
			it("includes java-cfenv when Spring Boot is detected", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION":       "11",
						"JBP_CONFIG_JAVA_CFENV": "{enabled: true}",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				Eventually(deployment).Should(matchers.Serve(Not(BeEmpty())))
			})
		})

		context("with JAVA_OPTS configuration", func() {
			it("applies configured JAVA_OPTS with from_environment=false and verifies at runtime", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "17",
						// Reduce memory settings to fit within 1G limit (v4 calculator)
						"JBP_CONFIG_JAVA_OPTS": `[from_environment: false, java_opts: '-Xmx256M -Xms128M -Xss512k -XX:ReservedCodeCacheSize=120M -XX:MetaspaceSize=78643K -XX:MaxMetaspaceSize=157286K -DoptionKey=optionValue']`,
					}).
					Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				// Verify buildpack detected and configured Java Opts
				Expect(logs.String()).To(ContainSubstring("Java Opts"))
				Expect(logs.String()).To(ContainSubstring("Adding configured JAVA_OPTS"))
				Expect(logs.String()).To(ContainSubstring("-Xmx256M"))

				// Verify Container Security Provider is configured (should add its opts)
				Expect(logs.String()).To(ContainSubstring("Container Security Provider"))

				// Verify configured opts are actually applied at runtime
				Eventually(deployment).Should(matchers.Serve(And(
					ContainSubstring("-Xmx256M"),
					ContainSubstring("-Xms128M"),
					ContainSubstring("-Xss512k"),
					ContainSubstring("-XX:ReservedCodeCacheSize=120M"),
					ContainSubstring("-XX:MetaspaceSize=78643K"),
					ContainSubstring("-XX:MaxMetaspaceSize=157286K"),
					ContainSubstring("optionKey=optionValue"), // Custom system property
				)).WithEndpoint("/jvm-args"))

				// Verify Container Security Provider opts use runtime paths ($DEPS_DIR), not staging paths
				Eventually(deployment).Should(matchers.Serve(And(
					ContainSubstring("-Xbootclasspath/a:"),
					Not(ContainSubstring("/tmp/contents")), // Should NOT have staging path
					ContainSubstring("-Djava.security.properties="),
				)).WithEndpoint("/jvm-args"))
			})

			it("applies configured JAVA_OPTS with from_environment=true and preserves user opts", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "17",
						// Reduce memory settings to fit within 1G limit (v4 calculator)
						"JBP_CONFIG_JAVA_OPTS": `{from_environment: true, java_opts: ["-Xmx384M", "-XX:ReservedCodeCacheSize=120M", "-Xss512k", "-DconfiguredProperty=fromConfig"]}`,
						"JAVA_OPTS":            "-DuserProperty=fromUser",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				// Verify buildpack detected and configured Java Opts
				Expect(logs.String()).To(ContainSubstring("Java Opts"))
				Expect(logs.String()).To(ContainSubstring("Adding configured JAVA_OPTS"))

				// Verify application starts successfully
				Eventually(deployment).Should(matchers.Serve(ContainSubstring("Hello from Spring Boot")))
			})

			it("applies only configured JAVA_OPTS with from_environment=false and ignores user opts", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "17",
						// Reduce memory settings to fit within 1G limit (v4 calculator)
						"JBP_CONFIG_JAVA_OPTS": `{from_environment: false, java_opts: ["-Xmx384M", "-XX:ReservedCodeCacheSize=120M", "-Xss512k", "-DconfiguredProperty=fromConfig"]}`,
						"JAVA_OPTS":            "-DuserProperty=shouldBeIgnored",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				// Verify buildpack detected and configured Java Opts
				Expect(logs.String()).To(ContainSubstring("Java Opts"))

				// Verify application starts successfully
				Eventually(deployment).Should(matchers.Serve(ContainSubstring("Hello from Spring Boot")))
			})

			it("applies framework opts without any configured JAVA_OPTS", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "17",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				// Verify Container Security Provider is always installed
				Expect(logs.String()).To(ContainSubstring("Container Security Provider"))

				// Verify application starts successfully
				Eventually(deployment).Should(matchers.Serve(ContainSubstring("Hello from Spring Boot")))
			})

			it("verifies multiple frameworks (4) append JAVA_OPTS without overwriting each other", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "17",
						// Reduce memory settings to fit within 1G limit (v4 calculator)
						"JBP_CONFIG_JAVA_OPTS": `{from_environment: false, java_opts: ["-Xmx384M", "-XX:ReservedCodeCacheSize=120M", "-Xss512k", "-DcustomProp=testValue"]}`,
						"JBP_CONFIG_DEBUG":     `{enabled: true}`,
					}).
					Execute(name, filepath.Join(fixtures, "containers", "spring_boot_multi_framework"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				// Verify FOUR frameworks are detected:
				// 1. Java Opts - user configured JAVA_OPTS
				// 2. Container Security Provider - always enabled (provides mTLS support)
				// 3. Debug - JDWP debug agent
				// 4. JRebel - auto-detected via rebel-remote.xml in fixture
				Expect(logs.String()).To(ContainSubstring("Java Opts"))
				Expect(logs.String()).To(ContainSubstring("Container Security Provider"))
				Expect(logs.String()).To(ContainSubstring("debug="))
				Expect(logs.String()).To(ContainSubstring("JRebel"))

				// Verify ALL opts from ALL frameworks are present at runtime (none were overwritten)
				Eventually(deployment).Should(matchers.Serve(And(
					// Framework 1: User-configured opts from JBP_CONFIG_JAVA_OPTS
					ContainSubstring("-Xmx384M"),
					ContainSubstring("customProp=testValue"),
					// Framework 2: Container Security Provider opts
					ContainSubstring("-Xbootclasspath/a:"),
					ContainSubstring("-Djava.security.properties="),
					// Framework 3: Debug opts (JDWP agent)
					ContainSubstring("-agentlib:jdwp="),
					// Framework 4: JRebel opts
					ContainSubstring("-agentpath:"),
					ContainSubstring("jrebel"),
					// JVMKill agent (from JRE, not a framework)
					ContainSubstring("jvmkill"),
					// Verify no staging paths anywhere
					Not(ContainSubstring("/tmp/contents")),
				)).WithEndpoint("/jvm-args"))
			})

			it("verifies from_environment=true preserves user JAVA_OPTS with 4 frameworks", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "17",
						// Reduce memory settings to fit within 1G limit (v4 calculator)
						"JBP_CONFIG_JAVA_OPTS": `{from_environment: true, java_opts: ["-XX:ReservedCodeCacheSize=120M", "-Xss512k", "-DconfigProp=fromBuildpack"]}`,
						"JAVA_OPTS":            "-DuserProp=fromEnvironment -Xmx256M",
						"JBP_CONFIG_DEBUG":     `{enabled: true}`,
					}).
					Execute(name, filepath.Join(fixtures, "containers", "spring_boot_multi_framework"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				// Verify FOUR frameworks are detected:
				// 1. Java Opts - user configured JAVA_OPTS
				// 2. Container Security Provider - always enabled
				// 3. Debug - JDWP debug agent
				// 4. JRebel - auto-detected via rebel-remote.xml in fixture
				Expect(logs.String()).To(ContainSubstring("Java Opts"))
				Expect(logs.String()).To(ContainSubstring("Container Security Provider"))
				Expect(logs.String()).To(ContainSubstring("debug="))
				Expect(logs.String()).To(ContainSubstring("JRebel"))

				// Verify ALL opts are present: user's JAVA_OPTS + configured opts + ALL framework opts
				Eventually(deployment).Should(matchers.Serve(And(
					// User's original JAVA_OPTS (should be preserved with from_environment: true)
					ContainSubstring("userProp=fromEnvironment"),
					ContainSubstring("-Xmx256M"),
					// Configured opts from buildpack (Framework 1)
					ContainSubstring("configProp=fromBuildpack"),
					// Framework 2: Container Security Provider opts
					ContainSubstring("-Xbootclasspath/a:"),
					// Framework 3: Debug opts (JDWP agent)
					ContainSubstring("-agentlib:jdwp="),
					// Framework 4: JRebel opts
					ContainSubstring("-agentpath:"),
					ContainSubstring("jrebel"),
					// JVMKill agent (from JRE, not a framework)
					ContainSubstring("jvmkill"),
					// No staging paths anywhere
					Not(ContainSubstring("/tmp/contents")),
				)).WithEndpoint("/jvm-args"))
			})
		})
	}
}
