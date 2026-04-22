package frameworks_test

import (
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/frameworks"
	"github.com/cloudfoundry/libbuildpack"
)

func newJavaCfEnvContext(buildDir, cacheDir, depsDir string) *common.Context {
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

var _ = Describe("Java CF Env", func() {
	var (
		fw       *frameworks.JavaCfEnvFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "jce-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "jce-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "jce-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewJavaCfEnvFramework(newJavaCfEnvContext(buildDir, cacheDir, depsDir))
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(cacheDir)
		os.RemoveAll(depsDir)
		os.Unsetenv("JBP_CONFIG_JAVA_CF_ENV")
	})

	Describe("Detect", func() {
		Context("with Spring Boot 3.x JAR in BOOT-INF/lib", func() {
			BeforeEach(func() {
				Expect(os.MkdirAll(filepath.Join(buildDir, "BOOT-INF", "lib"), 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(buildDir, "BOOT-INF", "lib", "spring-boot-3.2.0.jar"), []byte("fake"), 0644)).To(Succeed())
			})

			It("returns 'Java CF Env'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Java CF Env"))
			})
		})

		Context("with Spring Boot 3.x JAR in lib/", func() {
			BeforeEach(func() {
				Expect(os.MkdirAll(filepath.Join(buildDir, "lib"), 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(buildDir, "lib", "spring-boot-3.1.5.jar"), []byte("fake"), 0644)).To(Succeed())
			})

			It("returns 'Java CF Env'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Java CF Env"))
			})
		})

		Context("with Spring Boot 3.x JAR in WEB-INF/lib", func() {
			BeforeEach(func() {
				Expect(os.MkdirAll(filepath.Join(buildDir, "WEB-INF", "lib"), 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(buildDir, "WEB-INF", "lib", "spring-boot-3.0.0.jar"), []byte("fake"), 0644)).To(Succeed())
			})

			It("returns 'Java CF Env'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Java CF Env"))
			})
		})

		Context("with Spring-Boot-Version: 3.x in META-INF/MANIFEST.MF", func() {
			BeforeEach(func() {
				Expect(os.MkdirAll(filepath.Join(buildDir, "META-INF"), 0755)).To(Succeed())
				Expect(os.WriteFile(
					filepath.Join(buildDir, "META-INF", "MANIFEST.MF"),
					[]byte("Manifest-Version: 1.0\nSpring-Boot-Version: 3.2.0\nMain-Class: org.springframework.boot.loader.JarLauncher\n"),
					0644,
				)).To(Succeed())
			})

			It("returns 'Java CF Env'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Java CF Env"))
			})
		})

		Context("with Spring Boot 2.x JAR (not 3.x)", func() {
			BeforeEach(func() {
				Expect(os.MkdirAll(filepath.Join(buildDir, "BOOT-INF", "lib"), 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(buildDir, "BOOT-INF", "lib", "spring-boot-2.7.5.jar"), []byte("fake"), 0644)).To(Succeed())
			})

			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with Spring-Boot-Version: 2.x in MANIFEST.MF", func() {
			BeforeEach(func() {
				Expect(os.MkdirAll(filepath.Join(buildDir, "META-INF"), 0755)).To(Succeed())
				Expect(os.WriteFile(
					filepath.Join(buildDir, "META-INF", "MANIFEST.MF"),
					[]byte("Manifest-Version: 1.0\nSpring-Boot-Version: 2.7.0\n"),
					0644,
				)).To(Succeed())
			})

			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with no Spring Boot present", func() {
			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("when java-cfenv is already in the application (BOOT-INF/lib)", func() {
			BeforeEach(func() {
				Expect(os.MkdirAll(filepath.Join(buildDir, "BOOT-INF", "lib"), 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(buildDir, "BOOT-INF", "lib", "spring-boot-3.2.0.jar"), []byte("fake"), 0644)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(buildDir, "BOOT-INF", "lib", "java-cfenv-2.4.0.jar"), []byte("fake"), 0644)).To(Succeed())
			})

			It("returns empty string (already present)", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("when java-cfenv is already in lib/", func() {
			BeforeEach(func() {
				Expect(os.MkdirAll(filepath.Join(buildDir, "lib"), 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(buildDir, "lib", "spring-boot-3.1.0.jar"), []byte("fake"), 0644)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(buildDir, "lib", "java-cfenv-boot-3.0.0.jar"), []byte("fake"), 0644)).To(Succeed())
			})

			It("returns empty string (already present)", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("when disabled via JBP_CONFIG_JAVA_CF_ENV", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_JAVA_CF_ENV", "{enabled: false}")
				Expect(os.MkdirAll(filepath.Join(buildDir, "BOOT-INF", "lib"), 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(buildDir, "BOOT-INF", "lib", "spring-boot-3.2.0.jar"), []byte("fake"), 0644)).To(Succeed())
			})

			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("when explicitly enabled via JBP_CONFIG_JAVA_CF_ENV", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_JAVA_CF_ENV", "{enabled: true}")
				Expect(os.MkdirAll(filepath.Join(buildDir, "BOOT-INF", "lib"), 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(buildDir, "BOOT-INF", "lib", "spring-boot-3.2.0.jar"), []byte("fake"), 0644)).To(Succeed())
			})

			It("returns 'Java CF Env'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Java CF Env"))
			})
		})
	})

	Describe("Finalize", func() {
		Context("when the JAR is present", func() {
			BeforeEach(func() {
				javaCfEnvDir := filepath.Join(depsDir, "0", "java_cf_env")
				Expect(os.MkdirAll(javaCfEnvDir, 0755)).To(Succeed())
				Expect(os.WriteFile(
					filepath.Join(javaCfEnvDir, "java-cfenv-3.1.0.jar"),
					[]byte("fake jar"),
					0644,
				)).To(Succeed())
			})

			It("writes a profile.d script", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "profile.d", "java_cf_env.sh")).To(BeAnExistingFile())
			})

			It("profile.d script exports CLASSPATH containing the JAR path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "java_cf_env.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("export CLASSPATH="))
				Expect(string(content)).To(ContainSubstring("java-cfenv-3.1.0.jar"))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR"))
			})

			It("profile.d script preserves existing CLASSPATH", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "java_cf_env.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("${CLASSPATH:+:$CLASSPATH}"))
			})

			It("runtime path includes the deps index", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "java_cf_env.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/java_cf_env/java-cfenv-3.1.0.jar"))
			})
		})

		Context("when no JAR is present", func() {
			It("succeeds without writing a profile.d script", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "profile.d", "java_cf_env.sh")).NotTo(BeAnExistingFile())
			})
		})

		Context("when a different JAR version is installed", func() {
			BeforeEach(func() {
				javaCfEnvDir := filepath.Join(depsDir, "0", "java_cf_env")
				Expect(os.MkdirAll(javaCfEnvDir, 0755)).To(Succeed())
				Expect(os.WriteFile(
					filepath.Join(javaCfEnvDir, "java-cfenv-2.5.0.jar"),
					[]byte("fake jar"),
					0644,
				)).To(Succeed())
			})

			It("references the correct JAR filename in the profile.d script", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "java_cf_env.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("java-cfenv-2.5.0.jar"))
			})
		})
	})
})
