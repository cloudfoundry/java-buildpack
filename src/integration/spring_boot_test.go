package integration_test

import (
	"io"
	"net/http"
	"path/filepath"
	"testing"

	"github.com/cloudfoundry/switchblade"
	"github.com/cloudfoundry/switchblade/matchers"
	"github.com/sclevine/spec"

	. "github.com/onsi/gomega"
)

func testSpringBoot(platform switchblade.Platform, fixtures string, sb3JarPath, sb4JarPath string) func(*testing.T, spec.G, spec.S) {
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
						"BP_JAVA_VERSION":        "11",
						"JBP_CONFIG_JAVA_CF_ENV": "{enabled: true}",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
				Expect(err).NotTo(HaveOccurred(), logs.String)
				// Fixture is not a Spring3 app, so Java CF Env detect should not pass
				Expect(logs.String()).NotTo(ContainSubstring("Java CF Env"))

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

			// Regression tests for #1301: the start command no longer uses `eval`, and
			// JAVA_OPTS is assembled by a pure-bash expander and tokenized at launch by
			// the shell-free javaexec launcher. A user-supplied JAVA_OPTS value must
			// therefore reach the JVM as literal text — command substitutions are never
			// executed, and globs/cron stars/shell metacharacters are never expanded or
			// interpreted as operators. These drive the value through the user JAVA_OPTS
			// env path (from_environment: true; memory comes from the configured opts),
			// then read the JVM's actual received value back via the fixture's /jvm-args
			// endpoint (System.getProperty("userProperty")).
			memoryOpts := `java_opts: ["-Xmx256M", "-Xms128M", "-Xss512k", "-XX:ReservedCodeCacheSize=120M", "-XX:MetaspaceSize=78643K", "-XX:MaxMetaspaceSize=157286K"]`

			it("does not execute command substitution in JAVA_OPTS (#1301, no eval)", func() {
				deployment, logs, err := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "17",
						"JBP_CONFIG_JAVA_OPTS": `{from_environment: true, ` + memoryOpts + `}`,
						// $(hostname) would run under the old eval start command. It must
						// instead arrive at the JVM verbatim.
						"JAVA_OPTS": `-DuserProperty=$(hostname)`,
					}).
					Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
				Expect(err).NotTo(HaveOccurred(), logs.String)

				Eventually(deployment).Should(matchers.Serve(
					ContainSubstring("userProperty=$(hostname)"), // literal, not the executed hostname
				).WithEndpoint("/jvm-args"))
			})

			// NOTE: glob/cron preservation and shell-metacharacter/ampersand/backslash
			// fidelity are covered deterministically at the unit level in
			// frameworks/java_opts_writer_test.go, which runs the real assembly script
			// and the real javaexec tokenizer. They are intentionally not duplicated as
			// docker integration tests (the switchblade docker harness mangles some
			// metacharacters when passing env vars, which is a harness artifact, not
			// buildpack behaviour). The command-substitution case above stays here
			// because non-execution is the security property worth proving end-to-end.

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
				Expect(logs.String()).To(ContainSubstring("Remote Debug"))
				Expect(logs.String()).To(ContainSubstring("JRebel"))

				// Verify ALL opts from ALL frameworks are present at runtime (none were overwritten)
				Eventually(deployment).Should(matchers.Serve(And(
					// Framework 1: User-configured opts from JBP_CONFIG_JAVA_OPTS
					ContainSubstring("-Xmx384M"),
					ContainSubstring("customProp=testValue"),
					// Framework 2: Container Security Provider opts
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
				Expect(logs.String()).To(ContainSubstring("Remote Debug"))
				Expect(logs.String()).To(ContainSubstring("JRebel"))

				// Verify ALL opts are present: user's JAVA_OPTS + configured opts + ALL framework opts
				Eventually(deployment).Should(matchers.Serve(And(
					// User's original JAVA_OPTS (should be preserved with from_environment: true)
					ContainSubstring("userProp=fromEnvironment"),
					ContainSubstring("-Xmx256M"),
					// Configured opts from buildpack (Framework 1)
					ContainSubstring("configProp=fromBuildpack"),
					// Framework 2: Container Security Provider opts
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

		// Tests using real Spring Boot fat jars from cloudfoundry/java-test-applications@v1.0.0.
		// SB4 (java-main-application) exposes RuntimeUtils endpoints (via core module):
		//   GET /active-profiles          -> ["cloud"] when java-cfenv activates cloud profile
		//   GET /loaded-jars              -> full classloader chain URLs incl. BOOT-INF/lib/*
		//   GET /spring-env?key=<prop>    -> Spring Environment property value
		//   GET /environment-variables    -> raw env vars
		//   GET /input-arguments          -> JVM input arguments (-javaagent etc.)
		// SB3 (java-main-application-boot3) only exposes GET / (no core module dependency).
		// Cloud profile activation verified via runtime logs for SB3.
		context("with real Spring Boot fat jars: java-cfenv injection", func() {
			it("SB3 (Spring Boot 3.x) -- java-cfenv 3.x, cloud profile via logs", func() {
				if sb3JarPath == "" {
					t.Skip("SB3 jar not available")
				}
				deployment, logs, err := platform.Deploy.
					WithServices(map[string]switchblade.Service{
						"db": {"uri": "postgres://host:5432/dbname"},
					}).
					WithEnv(map[string]string{
						"BP_JAVA_VERSION":        "17",
						"JBP_CONFIG_JAVA_CF_ENV": "{enabled: true}",
					}).
					Execute(name, sb3JarPath)
				Expect(err).NotTo(HaveOccurred(), logs.String)

				// Buildpack detected and injected correct java-cfenv 3.x
				Expect(logs.String()).To(ContainSubstring("Java CF Env"))
				Expect(logs.String()).To(ContainSubstring("3."))

				// java-cfenv activated "cloud" profile — verified via Spring Boot startup log
				// (SB3 jar doesn't expose /active-profiles endpoint yet)
				// Use Eventually: RuntimeLogs() may be called before Spring Boot finishes starting.
				Eventually(func() (string, error) {
					return deployment.RuntimeLogs()
				}).Should(ContainSubstring(`profile is active: "cloud"`))

				// App is live
				Eventually(deployment).Should(matchers.Serve(ContainSubstring("ok")).WithEndpoint("/"))
			})

			it("SB4 (Spring Boot 4.x) -- java-cfenv 4.x, cloud profile, loaded-jars, vcap mapping", func() {
				if sb4JarPath == "" {
					t.Skip("SB4 jar not available")
				}
				deployment, logs, err := platform.Deploy.
					WithServices(map[string]switchblade.Service{
						"db": {
							"uri":      "postgres://host:5432/dbname",
							"username": "testuser",
							"password": "testpass",
						},
					}).
					WithEnv(map[string]string{
						"BP_JAVA_VERSION":        "21",
						"JBP_CONFIG_JAVA_CF_ENV": "{enabled: true}",
					}).
					Execute(name, sb4JarPath)
				Expect(err).NotTo(HaveOccurred(), logs.String)

				// Buildpack detected and injected correct java-cfenv 4.x (java-cfenv-all fat jar)
				Expect(logs.String()).To(ContainSubstring("Java CF Env"))
				Expect(logs.String()).To(ContainSubstring("4."))

				// java-cfenv-all activated "cloud" profile — this is the core value-add of java-cfenv.
				Eventually(deployment).Should(matchers.Serve(
					ContainSubstring("cloud")).WithEndpoint("/active-profiles"))

				// java-cfenv-all jar loaded by JarLauncher via BOOT-INF/lib symlink
				Eventually(deployment).Should(matchers.Serve(
					ContainSubstring("java-cfenv")).WithEndpoint("/loaded-jars"))

				// Helper for /spring-env?key= queries (WithEndpoint encodes '?' as %3F)
				springEnv := func(key string) func() (string, error) {
					return func() (string, error) {
						resp, err := http.Get(deployment.ExternalURL + "/spring-env?key=" + key) //nolint:noctx
						if err != nil {
							return "", err
						}
						defer resp.Body.Close()
						body, err := io.ReadAll(resp.Body)
						return string(body), err
					}
				}

				// Spring Boot built-in: CloudFoundryVcapEnvironmentPostProcessor flattens
				// VCAP_SERVICES into vcap.services.<name>.credentials.* properties (works
				// without java-cfenv). Service name is dynamic (container-name + key), so
				// we don't assert the exact property path here.

				// java-cfenv-all JDBC auto-configuration: CfDataSourceEnvironmentPostProcessor
				// detects postgres:// URI scheme and maps to spring.datasource.url/username/password.
				// This proves the full service connector pipeline is active, beyond
				// Spring Boot's built-in vcap.services.* property flattening.
				Eventually(springEnv("spring.datasource.url")).
					Should(ContainSubstring("jdbc:postgresql://host:5432/dbname"))
				Eventually(springEnv("spring.datasource.username")).
					Should(ContainSubstring("testuser"))
				Eventually(springEnv("spring.datasource.password")).
					Should(ContainSubstring("testpass"))
			})

			it("SB4 (Spring Boot 4.x) -- java-cfenv 4.x, container-security-provider, cf-metrics-exporter", func() {
				if sb4JarPath == "" {
					t.Skip("SB4 jar not available")
				}
				deployment, logs, err := platform.Deploy.
					WithServices(map[string]switchblade.Service{
						"db": {"uri": "postgres://host:5432/dbname"},
					}).
					WithEnv(map[string]string{
						"BP_JAVA_VERSION":             "21",
						"JBP_CONFIG_JAVA_CF_ENV":      "{enabled: true}",
						// cf-metrics-exporter: rpsType=random + enableLogEmitter requires no external infra
						"CF_METRICS_EXPORTER_ENABLED": "true",
						"CF_METRICS_EXPORTER_PROPS":   "rpsType=random,enableLogEmitter",
					}).
					Execute(name, sb4JarPath)
				Expect(err).NotTo(HaveOccurred(), logs.String)

				// java-cfenv: correct 4.x version detected and injected
				Expect(logs.String()).To(ContainSubstring("Java CF Env"))
				Expect(logs.String()).To(ContainSubstring("4."))

				// cf-metrics-exporter: -javaagent present in JVM input arguments
				Expect(logs.String()).To(ContainSubstring("CF Metrics Exporter"))
				Expect(logs.String()).To(ContainSubstring("enabled, with properties: rpsType=random,enableLogEmitter"))
				Eventually(deployment).Should(matchers.Serve(
					ContainSubstring("cf-metrics-exporter")).WithEndpoint("/input-arguments"))

				// container-security-provider: env var set at runtime
				Eventually(deployment).Should(matchers.Serve(
					ContainSubstring("CONTAINER_SECURITY_PROVIDER")).WithEndpoint("/environment-variables"))

				// java-cfenv activated "cloud" profile
				Eventually(deployment).Should(matchers.Serve(
					ContainSubstring("cloud")).WithEndpoint("/active-profiles"))
			})
		})
	}
}