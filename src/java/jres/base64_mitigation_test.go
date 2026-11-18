package jres_test

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/jres"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("CVE-2026-114938 Base64 intrinsics mitigation", func() {
	const mitigation = "-XX:-UseBASE64Intrinsics"

	var (
		ctx    *common.Context
		logBuf *bytes.Buffer
	)

	BeforeEach(func() {
		logBuf = &bytes.Buffer{}
		var cleanup func()
		ctx, cleanup = makeTestContextWithBuffer(logBuf)
		clearJREEnvVars()
		DeferCleanup(cleanup)
		DeferCleanup(clearJREEnvVars)
		DeferCleanup(os.Unsetenv, "JAVA_HOME")
	})

	jreOpts := func() string {
		content, err := os.ReadFile(filepath.Join(ctx.Stager.DepDir(), "java_opts", "05_jre.opts"))
		Expect(err).NotTo(HaveOccurred())
		return string(content)
	}

	jvms := map[string]struct {
		newJRE func(*common.Context) jres.JRE
		envVar string
	}{
		"OpenJDK": {func(c *common.Context) jres.JRE { return jres.NewOpenJDKJRE(c) }, "JBP_CONFIG_OPEN_JDK_JRE"},
	}

	for name, jvm := range jvms {
		name, jvm := name, jvm

		Describe(name, func() {
			DescribeTable("adds the option only for releases without the fix",
				func(javaVersion string, expected bool) {
					createFakeJRE(ctx, "", javaVersion)
					Expect(jvm.newJRE(ctx).Finalize()).To(Succeed())

					if expected {
						Expect(jreOpts()).To(ContainSubstring(mitigation))
						Expect(logBuf.String()).To(ContainSubstring("CVE-2026-114938"))
					} else {
						Expect(jreOpts()).NotTo(ContainSubstring("UseBASE64Intrinsics"))
						Expect(logBuf.String()).NotTo(ContainSubstring("CVE-2026-114938"))
					}
				},
				Entry("Java 17 before the fix", "17.0.21.0.3", true),
				Entry("Java 17 with the fix", "17.0.21.1", false),
				Entry("Java 17 after the fix", "17.0.22", false),
				Entry("Java 17 without the vulnerable decoder", "17.0.5", false),
				Entry("Java 21 before the fix", "21.0.13.0.3", true),
				Entry("Java 21 with the fix", "21.0.13.1", false),
				Entry("Java 25 before the fix", "25.0.5.0.3", true),
				Entry("Java 25 before the fix, three segments", "25.0.5", true),
				Entry("Java 25 with the fix", "25.0.5.1", false),
				Entry("Java 25 after the fix", "25.0.6", false),
				Entry("Java 26 has no known fixed release", "26.0.2.1", true),
				Entry("Java 11, which does not know the option", "11.0.33.0.3", false),
				Entry("Java 8, which does not know the option", "1.8.0_513", false),
			)

			It("can be turned off by the application", func() {
				Expect(os.Setenv(jvm.envVar, "{base64_intrinsics_mitigation: {enabled: false}}")).To(Succeed())
				createFakeJRE(ctx, "", "25.0.5.0.3")
				Expect(jvm.newJRE(ctx).Finalize()).To(Succeed())

				Expect(jreOpts()).NotTo(ContainSubstring("UseBASE64Intrinsics"))
				Expect(logBuf.String()).To(ContainSubstring("disabled by configuration"))
			})

			It("stays on when other settings are configured", func() {
				Expect(os.Setenv(jvm.envVar, "{memory_calculator: {stack_threads: 100}}")).To(Succeed())
				createFakeJRE(ctx, "", "25.0.5.0.3")
				Expect(jvm.newJRE(ctx).Finalize()).To(Succeed())

				Expect(jreOpts()).To(ContainSubstring(mitigation))
			})

			It("stays on when the configuration cannot be parsed", func() {
				Expect(os.Setenv(jvm.envVar, "{base64_intrinsics_mitigation: [")).To(Succeed())
				createFakeJRE(ctx, "", "25.0.5.0.3")
				Expect(jvm.newJRE(ctx).Finalize()).To(Succeed())

				Expect(jreOpts()).To(ContainSubstring(mitigation))
			})

			It("adds nothing and warns when the version cannot be determined", func() {
				javaHome := createFakeJRE(ctx, "", "25.0.5.0.3")
				Expect(os.Remove(filepath.Join(javaHome, "release"))).To(Succeed())
				Expect(jvm.newJRE(ctx).Finalize()).To(Succeed())

				Expect(jreOpts()).NotTo(ContainSubstring("UseBASE64Intrinsics"))
				Expect(logBuf.String()).To(ContainSubstring("Could not determine"))
			})
		})
	}

	Describe("JDK_JAVA_OPTIONS for JVMs that are not started with JAVA_OPTS", func() {
		const scriptName = "base64_intrinsics_mitigation.sh"

		scriptPath := func() string {
			return filepath.Join(ctx.Stager.DepDir(), "profile.d", scriptName)
		}

		// sourceScript runs the generated profile.d script in bash, like the container does, and returns JDK_JAVA_OPTIONS.
		sourceScript := func(initial string, times int) string {
			command := ""
			for i := 0; i < times; i++ {
				command += ". " + scriptPath() + "; "
			}
			command += "printf '%s' \"$JDK_JAVA_OPTIONS\""
			cmd := exec.Command("bash", "-c", command)
			cmd.Env = []string{"JDK_JAVA_OPTIONS=" + initial}
			output, err := cmd.Output()
			Expect(err).NotTo(HaveOccurred())
			return string(output)
		}

		finalize := func(javaVersion string, env map[string]string) {
			for key, value := range env {
				Expect(os.Setenv(key, value)).To(Succeed())
			}
			createFakeJRE(ctx, "", javaVersion)
			Expect(jres.NewOpenJDKJRE(ctx).Finalize()).To(Succeed())
		}

		It("is exported with the option for an affected JRE", func() {
			finalize("25.0.5.0.3", nil)

			Expect(scriptPath()).To(BeAnExistingFile())
			Expect(sourceScript("", 1)).To(Equal("-XX:-UseBASE64Intrinsics"))
		})

		It("keeps the JDK_JAVA_OPTIONS of the application", func() {
			finalize("25.0.5.0.3", nil)

			Expect(sourceScript("-Dapp.setting=1", 1)).To(Equal("-Dapp.setting=1 -XX:-UseBASE64Intrinsics"))
		})

		It("does not add the option twice when the script is sourced again", func() {
			finalize("25.0.5.0.3", nil)

			Expect(sourceScript("", 2)).To(Equal("-XX:-UseBASE64Intrinsics"))
		})

		It("is not written for a JRE that contains the fix", func() {
			finalize("25.0.5.1", nil)

			Expect(scriptPath()).NotTo(BeAnExistingFile())
		})

		It("is not written for Java 8", func() {
			finalize("1.8.0_513", nil)

			Expect(scriptPath()).NotTo(BeAnExistingFile())
		})

		It("can be turned off separately and keeps the JAVA_OPTS mitigation", func() {
			finalize("25.0.5.0.3", map[string]string{"JBP_CONFIG_OPEN_JDK_JRE": "{base64_intrinsics_mitigation: {jdk_java_options: false}}"})

			Expect(scriptPath()).NotTo(BeAnExistingFile())
			Expect(jreOpts()).To(ContainSubstring(mitigation))
		})

		It("is turned off together with the whole mitigation", func() {
			finalize("25.0.5.0.3", map[string]string{"JBP_CONFIG_OPEN_JDK_JRE": "{base64_intrinsics_mitigation: {enabled: false}}"})

			Expect(scriptPath()).NotTo(BeAnExistingFile())
			Expect(jreOpts()).NotTo(ContainSubstring("UseBASE64Intrinsics"))
		})
	})

	DescribeTable("is not added to JREs that are not covered (Zulu and SapMachine already ship fixed releases)",
		func(newJRE func(*common.Context) jres.JRE) {
			createFakeJRE(ctx, "", "25.0.5.0.3")
			Expect(newJRE(ctx).Finalize()).To(Succeed())

			Expect(jreOpts()).NotTo(ContainSubstring("UseBASE64Intrinsics"))
		},
		Entry("Zulu", func(c *common.Context) jres.JRE { return jres.NewZuluJRE(c) }),
		Entry("SapMachine", func(c *common.Context) jres.JRE { return jres.NewSapMachineJRE(c) }),
		Entry("GraalVM", func(c *common.Context) jres.JRE { return jres.NewGraalVMJRE(c) }),
		Entry("Oracle", func(c *common.Context) jres.JRE { return jres.NewOracleJRE(c) }),
		Entry("IBM", func(c *common.Context) jres.JRE { return jres.NewIBMJRE(c) }),
	)
})
