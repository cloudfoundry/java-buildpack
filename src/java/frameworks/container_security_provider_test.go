package frameworks_test

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/frameworks"
	"github.com/cloudfoundry/libbuildpack"
)

func newCSPContext(buildDir, cacheDir, depsDir string) *common.Context {
	logger := libbuildpack.NewLogger(GinkgoWriter)
	manifest := &libbuildpack.Manifest{}
	installer := &libbuildpack.Installer{}
	stager := libbuildpack.NewStager([]string{buildDir, cacheDir, depsDir, "0"}, logger, manifest)
	return &common.Context{
		Stager:    stager,
		Manifest:  manifest,
		Installer: installer,
		Log:       logger,
		Command:   &libbuildpack.Command{},
	}
}

// writeJavaReleaseFile creates a $JAVA_HOME/release file so DetermineJavaVersion resolves correctly.
func writeJavaReleaseFile(javaHome, version string) {
	Expect(os.MkdirAll(javaHome, 0755)).To(Succeed())
	Expect(os.WriteFile(
		filepath.Join(javaHome, "release"),
		[]byte(fmt.Sprintf("JAVA_VERSION=\"%s\"\n", version)),
		0644,
	)).To(Succeed())
}

var _ = Describe("Container Security Provider", func() {
	Describe("Java version specific handling", func() {
		DescribeTable("uses appropriate mechanism for Java version",
			func(javaVersion int, expectedType string) {
				var mechanism string
				if javaVersion >= 9 {
					mechanism = "bootclasspath"
				} else {
					mechanism = "extension"
				}

				Expect(mechanism).To(Equal(expectedType))
			},
			Entry("Java 8 uses extension directory", 8, "extension"),
			Entry("Java 9 uses bootstrap classpath", 9, "bootclasspath"),
			Entry("Java 11 uses bootstrap classpath", 11, "bootclasspath"),
			Entry("Java 17 uses bootstrap classpath", 17, "bootclasspath"),
		)
	})

	Describe("ContainerSecurityProviderFramework", func() {
		var (
			fw       *frameworks.ContainerSecurityProviderFramework
			buildDir string
			cacheDir string
			depsDir  string
		)

		BeforeEach(func() {
			var err error
			buildDir, err = os.MkdirTemp("", "csp-build")
			Expect(err).NotTo(HaveOccurred())
			cacheDir, err = os.MkdirTemp("", "csp-cache")
			Expect(err).NotTo(HaveOccurred())
			depsDir, err = os.MkdirTemp("", "csp-deps")
			Expect(err).NotTo(HaveOccurred())
			Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

			fw = frameworks.NewContainerSecurityProviderFramework(newCSPContext(buildDir, cacheDir, depsDir))
		})

		AfterEach(func() {
			os.RemoveAll(buildDir)
			os.RemoveAll(cacheDir)
			os.RemoveAll(depsDir)
			os.Unsetenv("JBP_CONFIG_CONTAINER_SECURITY_PROVIDER")
			os.Unsetenv("JAVA_HOME")
		})

		Describe("Detect", func() {
			It("always returns 'Container Security Provider'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Container Security Provider"))
			})
		})

		Describe("Finalize", func() {
			Context("when no JAR is present", func() {
				It("succeeds without writing any files", func() {
					Expect(fw.Finalize()).To(Succeed())
					optsFile := filepath.Join(depsDir, "0", "java_opts", "17_container_security.opts")
					Expect(optsFile).NotTo(BeAnExistingFile())
				})
			})

			Context("when the JAR is present (Java 9+)", func() {
				BeforeEach(func() {
					javaHome, err := os.MkdirTemp("", "java-home")
					Expect(err).NotTo(HaveOccurred())
					writeJavaReleaseFile(javaHome, "17.0.13")
					os.Setenv("JAVA_HOME", javaHome)

					providerDir := filepath.Join(depsDir, "0", "container_security_provider")
					Expect(os.MkdirAll(providerDir, 0755)).To(Succeed())
					Expect(os.WriteFile(
						filepath.Join(providerDir, "container-security-provider-1.20.0-RELEASE.jar"),
						[]byte("fake jar"),
						0644,
					)).To(Succeed())
				})

				It("writes a profile.d script", func() {
					Expect(fw.Finalize()).To(Succeed())
					Expect(filepath.Join(depsDir, "0", "profile.d", "container_security_provider.sh")).To(BeAnExistingFile())
				})

				It("profile.d script exports CONTAINER_SECURITY_PROVIDER pointing to the JAR", func() {
					Expect(fw.Finalize()).To(Succeed())
					content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "container_security_provider.sh"))
					Expect(err).NotTo(HaveOccurred())
					Expect(string(content)).To(ContainSubstring("export CONTAINER_SECURITY_PROVIDER="))
					Expect(string(content)).To(ContainSubstring("container-security-provider-1.20.0-RELEASE.jar"))
					Expect(string(content)).To(ContainSubstring("$DEPS_DIR"))
				})

				It("writes the opts file with java.security.properties flag", func() {
					Expect(fw.Finalize()).To(Succeed())
					optsFile := filepath.Join(depsDir, "0", "java_opts", "17_container_security.opts")
					Expect(optsFile).To(BeAnExistingFile())
					content, err := os.ReadFile(optsFile)
					Expect(err).NotTo(HaveOccurred())
					Expect(string(content)).To(ContainSubstring("-Djava.security.properties="))
					Expect(string(content)).To(ContainSubstring("java.security"))
				})

				It("writes a java.security file inside the provider dir", func() {
					Expect(fw.Finalize()).To(Succeed())
					secFile := filepath.Join(depsDir, "0", "container_security_provider", "java.security")
					Expect(secFile).To(BeAnExistingFile())
				})

				It("java.security file places CloudFoundryContainerProvider at position 1", func() {
					Expect(fw.Finalize()).To(Succeed())
					content, err := os.ReadFile(filepath.Join(depsDir, "0", "container_security_provider", "java.security"))
					Expect(err).NotTo(HaveOccurred())
					Expect(string(content)).To(ContainSubstring("security.provider.1=org.cloudfoundry.security.CloudFoundryContainerProvider"))
				})

				It("java.security file disables JVM DNS caching", func() {
					Expect(fw.Finalize()).To(Succeed())
					content, err := os.ReadFile(filepath.Join(depsDir, "0", "container_security_provider", "java.security"))
					Expect(err).NotTo(HaveOccurred())
					Expect(string(content)).To(ContainSubstring("networkaddress.cache.ttl=0"))
					Expect(string(content)).To(ContainSubstring("networkaddress.cache.negative.ttl=0"))
				})
			})

			Context("when the JAR is present (Java 8)", func() {
				BeforeEach(func() {
					javaHome, err := os.MkdirTemp("", "java-home")
					Expect(err).NotTo(HaveOccurred())
					writeJavaReleaseFile(javaHome, "1.8.0_422")
					os.Setenv("JAVA_HOME", javaHome)

					providerDir := filepath.Join(depsDir, "0", "container_security_provider")
					Expect(os.MkdirAll(providerDir, 0755)).To(Succeed())
					Expect(os.WriteFile(
						filepath.Join(providerDir, "container-security-provider-1.20.0-RELEASE.jar"),
						[]byte("fake jar"),
						0644,
					)).To(Succeed())
				})

				It("does not write a profile.d script (uses ext dirs instead)", func() {
					Expect(fw.Finalize()).To(Succeed())
					Expect(filepath.Join(depsDir, "0", "profile.d", "container_security_provider.sh")).NotTo(BeAnExistingFile())
				})

				It("writes opts file with -Djava.ext.dirs flag", func() {
					Expect(fw.Finalize()).To(Succeed())
					optsFile := filepath.Join(depsDir, "0", "java_opts", "17_container_security.opts")
					Expect(optsFile).To(BeAnExistingFile())
					content, err := os.ReadFile(optsFile)
					Expect(err).NotTo(HaveOccurred())
					Expect(string(content)).To(ContainSubstring("-Djava.ext.dirs="))
				})
			})

			Context("key_manager_enabled configuration", func() {
				BeforeEach(func() {
					javaHome, err := os.MkdirTemp("", "java-home")
					Expect(err).NotTo(HaveOccurred())
					writeJavaReleaseFile(javaHome, "17.0.13")
					os.Setenv("JAVA_HOME", javaHome)

					providerDir := filepath.Join(depsDir, "0", "container_security_provider")
					Expect(os.MkdirAll(providerDir, 0755)).To(Succeed())
					Expect(os.WriteFile(
						filepath.Join(providerDir, "container-security-provider-1.20.0-RELEASE.jar"),
						[]byte("fake jar"),
						0644,
					)).To(Succeed())
				})

				It("appends -Dorg.cloudfoundry.security.keymanager.enabled when set", func() {
					os.Setenv("JBP_CONFIG_CONTAINER_SECURITY_PROVIDER", "key_manager_enabled: \"false\"")
					Expect(fw.Finalize()).To(Succeed())
					content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "17_container_security.opts"))
					Expect(err).NotTo(HaveOccurred())
					Expect(string(content)).To(ContainSubstring("-Dorg.cloudfoundry.security.keymanager.enabled=false"))
				})

				It("does not append key manager flag when not configured", func() {
					Expect(fw.Finalize()).To(Succeed())
					content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "17_container_security.opts"))
					Expect(err).NotTo(HaveOccurred())
					Expect(string(content)).NotTo(ContainSubstring("keymanager.enabled"))
				})
			})

			Context("trust_manager_enabled configuration", func() {
				BeforeEach(func() {
					javaHome, err := os.MkdirTemp("", "java-home")
					Expect(err).NotTo(HaveOccurred())
					writeJavaReleaseFile(javaHome, "17.0.13")
					os.Setenv("JAVA_HOME", javaHome)

					providerDir := filepath.Join(depsDir, "0", "container_security_provider")
					Expect(os.MkdirAll(providerDir, 0755)).To(Succeed())
					Expect(os.WriteFile(
						filepath.Join(providerDir, "container-security-provider-1.20.0-RELEASE.jar"),
						[]byte("fake jar"),
						0644,
					)).To(Succeed())
				})

				It("appends -Dorg.cloudfoundry.security.trustmanager.enabled when set", func() {
					os.Setenv("JBP_CONFIG_CONTAINER_SECURITY_PROVIDER", "trust_manager_enabled: \"true\"")
					Expect(fw.Finalize()).To(Succeed())
					content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "17_container_security.opts"))
					Expect(err).NotTo(HaveOccurred())
					Expect(string(content)).To(ContainSubstring("-Dorg.cloudfoundry.security.trustmanager.enabled=true"))
				})

				It("does not append trust manager flag when not configured", func() {
					Expect(fw.Finalize()).To(Succeed())
					content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "17_container_security.opts"))
					Expect(err).NotTo(HaveOccurred())
					Expect(string(content)).NotTo(ContainSubstring("trustmanager.enabled"))
				})
			})

			Context("when JAVA_HOME points to a JDK with existing security providers", func() {
				BeforeEach(func() {
					javaHome, err := os.MkdirTemp("", "java-home")
					Expect(err).NotTo(HaveOccurred())
					writeJavaReleaseFile(javaHome, "17.0.13")

					// Write a java.security file at the Java 9+ location
					secDir := filepath.Join(javaHome, "conf", "security")
					Expect(os.MkdirAll(secDir, 0755)).To(Succeed())
					Expect(os.WriteFile(filepath.Join(secDir, "java.security"), []byte(
						"security.provider.1=sun.security.provider.Sun\n"+
							"security.provider.2=sun.security.rsa.SunRsaSign\n",
					), 0644)).To(Succeed())
					os.Setenv("JAVA_HOME", javaHome)

					providerDir := filepath.Join(depsDir, "0", "container_security_provider")
					Expect(os.MkdirAll(providerDir, 0755)).To(Succeed())
					Expect(os.WriteFile(
						filepath.Join(providerDir, "container-security-provider-1.20.0-RELEASE.jar"),
						[]byte("fake jar"),
						0644,
					)).To(Succeed())
				})

				It("inserts CloudFoundryContainerProvider before existing providers", func() {
					Expect(fw.Finalize()).To(Succeed())
					content, err := os.ReadFile(filepath.Join(depsDir, "0", "container_security_provider", "java.security"))
					Expect(err).NotTo(HaveOccurred())
					lines := strings.Split(string(content), "\n")
					var providerLines []string
					for _, l := range lines {
						if strings.HasPrefix(l, "security.provider.") {
							providerLines = append(providerLines, l)
						}
					}
					Expect(providerLines[0]).To(ContainSubstring("security.provider.1=org.cloudfoundry.security.CloudFoundryContainerProvider"))
					Expect(providerLines[1]).To(ContainSubstring("security.provider.2=sun.security.provider.Sun"))
					Expect(providerLines[2]).To(ContainSubstring("security.provider.3=sun.security.rsa.SunRsaSign"))
				})
			})
		})
	})
})
