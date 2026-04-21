package frameworks_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"os"
	"path/filepath"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/frameworks"
	"github.com/cloudfoundry/libbuildpack"
)

func newCCMContext(buildDir, cacheDir, depsDir string) *common.Context {
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

var _ = Describe("Client Certificate Mapper", func() {
	AfterEach(func() {
		os.Unsetenv("JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER")
	})

	Describe("ClientCertificateMapperFramework", func() {
		var (
			fw       *frameworks.ClientCertificateMapperFramework
			buildDir string
			cacheDir string
			depsDir  string
		)

		BeforeEach(func() {
			var err error
			buildDir, err = os.MkdirTemp("", "ccm-build")
			Expect(err).NotTo(HaveOccurred())
			cacheDir, err = os.MkdirTemp("", "ccm-cache")
			Expect(err).NotTo(HaveOccurred())
			depsDir, err = os.MkdirTemp("", "ccm-deps")
			Expect(err).NotTo(HaveOccurred())
			Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

			fw = frameworks.NewClientCertificateMapperFramework(newCCMContext(buildDir, cacheDir, depsDir))
		})

		AfterEach(func() {
			os.RemoveAll(buildDir)
			os.RemoveAll(cacheDir)
			os.RemoveAll(depsDir)
			os.Unsetenv("JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER")
		})

		Describe("Detect", func() {
			Context("with no configuration set", func() {
				It("returns 'Client Certificate Mapper'", func() {
					name, err := fw.Detect()
					Expect(err).NotTo(HaveOccurred())
					Expect(name).To(Equal("Client Certificate Mapper"))
				})
			})

			Context("with enabled: true in JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER", func() {
				BeforeEach(func() {
					os.Setenv("JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER", "enabled: true")
				})

				It("returns 'Client Certificate Mapper'", func() {
					name, err := fw.Detect()
					Expect(err).NotTo(HaveOccurred())
					Expect(name).To(Equal("Client Certificate Mapper"))
				})
			})

			Context("with enabled: false in JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER", func() {
				BeforeEach(func() {
					os.Setenv("JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER", "enabled: false")
				})

				It("returns empty string", func() {
					name, err := fw.Detect()
					Expect(err).NotTo(HaveOccurred())
					Expect(name).To(BeEmpty())
				})
			})

			Context("with YAML inline syntax disabled", func() {
				BeforeEach(func() {
					os.Setenv("JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER", "{enabled: false}")
				})

				It("returns empty string", func() {
					name, err := fw.Detect()
					Expect(err).NotTo(HaveOccurred())
					Expect(name).To(BeEmpty())
				})
			})

			Context("with invalid YAML in JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER", func() {
				BeforeEach(func() {
					os.Setenv("JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER", "{{invalid}")
				})

				It("returns empty string without error (fail-safe)", func() {
					name, err := fw.Detect()
					Expect(err).NotTo(HaveOccurred())
					Expect(name).To(BeEmpty())
				})
			})

			Context("with an unrelated key in config", func() {
				BeforeEach(func() {
					os.Setenv("JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER", "some_other_key: value")
				})

				It("defaults to enabled", func() {
					name, err := fw.Detect()
					Expect(err).NotTo(HaveOccurred())
					Expect(name).To(Equal("Client Certificate Mapper"))
				})
			})
		})

		Describe("Finalize", func() {
			Context("when the JAR is present in the dep dir", func() {
				BeforeEach(func() {
					mapperDir := filepath.Join(depsDir, "0", "client_certificate_mapper")
					Expect(os.MkdirAll(mapperDir, 0755)).To(Succeed())
					Expect(os.WriteFile(
						filepath.Join(mapperDir, "client-certificate-mapper-2.0.1.jar"),
						[]byte("fake jar"),
						0644,
					)).To(Succeed())
				})

				It("writes a profile.d script", func() {
					Expect(fw.Finalize()).To(Succeed())
					profileScript := filepath.Join(depsDir, "0", "profile.d", "client_certificate_mapper.sh")
					Expect(profileScript).To(BeAnExistingFile())
				})

				It("profile.d script exports CLASSPATH containing the JAR path", func() {
					Expect(fw.Finalize()).To(Succeed())
					profileScript := filepath.Join(depsDir, "0", "profile.d", "client_certificate_mapper.sh")
					content, err := os.ReadFile(profileScript)
					Expect(err).NotTo(HaveOccurred())
					Expect(string(content)).To(ContainSubstring("export CLASSPATH="))
					Expect(string(content)).To(ContainSubstring("client-certificate-mapper-2.0.1.jar"))
					Expect(string(content)).To(ContainSubstring("$DEPS_DIR"))
				})

				It("profile.d script preserves existing CLASSPATH entries", func() {
					Expect(fw.Finalize()).To(Succeed())
					content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "client_certificate_mapper.sh"))
					Expect(err).NotTo(HaveOccurred())
					Expect(string(content)).To(ContainSubstring("${CLASSPATH:+:$CLASSPATH}"))
				})
			})

			Context("when no JAR is present in the dep dir", func() {
				It("succeeds without writing a profile.d script", func() {
					Expect(fw.Finalize()).To(Succeed())
					profileScript := filepath.Join(depsDir, "0", "profile.d", "client_certificate_mapper.sh")
					Expect(profileScript).NotTo(BeAnExistingFile())
				})
			})

			Context("when multiple JAR versions exist", func() {
				BeforeEach(func() {
					mapperDir := filepath.Join(depsDir, "0", "client_certificate_mapper")
					Expect(os.MkdirAll(mapperDir, 0755)).To(Succeed())
					Expect(os.WriteFile(filepath.Join(mapperDir, "client-certificate-mapper-2.0.1.jar"), []byte("jar"), 0644)).To(Succeed())
				})

				It("references the found JAR in the profile.d script", func() {
					Expect(fw.Finalize()).To(Succeed())
					content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "client_certificate_mapper.sh"))
					Expect(err).NotTo(HaveOccurred())
					Expect(string(content)).To(ContainSubstring("client-certificate-mapper-2.0.1.jar"))
				})
			})
		})
	})
})
