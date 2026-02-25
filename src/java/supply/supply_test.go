package supply_test

import (
	"github.com/cloudfoundry/java-buildpack/src/internal/mocks"
	"github.com/golang/mock/gomock"
	"os"
	"path/filepath"
	"time"

	"github.com/cloudfoundry/java-buildpack/src/java/supply"
	"github.com/cloudfoundry/libbuildpack"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Supply", func() {
	var (
		buildDir      string
		cacheDir      string
		depsDir       string
		depsIdx       string
		mockCtrl      *gomock.Controller
		mockManifest  *mocks.MockManifest
		mockInstaller *mocks.MockInstaller
		supplier      *supply.Supplier
		stager        *libbuildpack.Stager
		logger        *libbuildpack.Logger
	)

	BeforeEach(func() {
		var err error

		// Create temp directories
		buildDir, err = os.MkdirTemp("", "supply-build")
		Expect(err).NotTo(HaveOccurred())

		cacheDir, err = os.MkdirTemp("", "supply-cache")
		Expect(err).NotTo(HaveOccurred())

		depsDir, err = os.MkdirTemp("", "supply-deps")
		Expect(err).NotTo(HaveOccurred())

		depsIdx = "0"

		// Create a mock buildpack directory with VERSION and manifest.yml files
		buildpackDir, err := os.MkdirTemp("", "supply-buildpack")
		Expect(err).NotTo(HaveOccurred())

		versionFile := filepath.Join(buildpackDir, "VERSION")
		Expect(os.WriteFile(versionFile, []byte("1.0.0"), 0644)).To(Succeed())

		manifestFile := filepath.Join(buildpackDir, "manifest.yml")
		manifestContent := `---
language: java
default_versions: []
dependencies: []
`
		Expect(os.WriteFile(manifestFile, []byte(manifestContent), 0644)).To(Succeed())

		// Create logger
		logger = libbuildpack.NewLogger(GinkgoWriter)

		mockCtrl = gomock.NewController(GinkgoT())
		mockManifest = mocks.NewMockManifest(mockCtrl)
		mockInstaller = mocks.NewMockInstaller(mockCtrl)

		// Create manifest with buildpack dir
		manifest, err := libbuildpack.NewManifest(buildpackDir, logger, time.Now())
		Expect(err).NotTo(HaveOccurred())

		// Create stager
		stager = libbuildpack.NewStager([]string{buildDir, cacheDir, depsDir, depsIdx}, logger, manifest)

		supplier = &supply.Supplier{
			Stager:    stager,
			Manifest:  mockManifest,
			Installer: mockInstaller,
			Log:       logger,
			Command:   &libbuildpack.Command{},
		}
	})

	AfterEach(func() {
		mockCtrl.Finish()

		os.RemoveAll(buildDir)
		os.RemoveAll(cacheDir)
		os.RemoveAll(depsDir)
	})

	Describe("Various Container Supply", func() {
		BeforeEach(func() {
			// create jdk install dir
			jdkInstallDir := filepath.Join(depsDir, depsIdx, "jre")
			Expect(os.MkdirAll(filepath.Join(jdkInstallDir), 0755)).To(Succeed())

			// create jvmkill install dir
			jvmkillInstallDir := filepath.Join(depsDir, depsIdx, "tmp", "jvmkill-install")
			Expect(os.MkdirAll(filepath.Join(jvmkillInstallDir), 0755)).To(Succeed())

			// create memory calculator install dir
			memCalcInstallDir := filepath.Join(depsDir, depsIdx, "tmp", "memory-calculator")
			Expect(os.MkdirAll(filepath.Join(jvmkillInstallDir), 0755)).To(Succeed())

			// create bin/java used to locate JAVA_HOME directory after JRE extraction
			Expect(os.MkdirAll(filepath.Join(jdkInstallDir, "jre-17.0.15", "bin"), 0755)).To(Succeed())
			javaBin := filepath.Join(jdkInstallDir, "jre-17.0.15", "bin", "java")
			Expect(os.WriteFile(javaBin, []byte("mockfile"), 0644)).To(Succeed())

			// adjust JRE  component mocks used during supply
			depJre := libbuildpack.Dependency{Name: "openjdk", Version: "17.0.15"}
			mockManifest.EXPECT().DefaultVersion("openjdk").Return(depJre, nil)
			depJVMKill := libbuildpack.Dependency{Name: "jvmkill", Version: "1.17.0"}
			mockManifest.EXPECT().DefaultVersion("jvmkill").Return(depJVMKill, nil)
			depMemCalc := libbuildpack.Dependency{Name: "memory-calculator", Version: "4.2.0"}
			mockManifest.EXPECT().DefaultVersion("memory-calculator").Return(depMemCalc, nil)

			mockInstaller.EXPECT().InstallDependency(depJre, jdkInstallDir).Return(nil)
			mockInstaller.EXPECT().InstallDependency(depJVMKill, jvmkillInstallDir).Return(nil)
			mockInstaller.EXPECT().InstallDependency(depMemCalc, memCalcInstallDir).Return(nil)

			ccmInstallDir := filepath.Join(depsDir, depsIdx, "client_certificate_mapper")
			Expect(os.MkdirAll(filepath.Join(ccmInstallDir), 0755)).To(Succeed())
			cspInstallDir := filepath.Join(depsDir, depsIdx, "container_security_provider")
			Expect(os.MkdirAll(filepath.Join(cspInstallDir), 0755)).To(Succeed())

			depClientCertificateMapper := libbuildpack.Dependency{Name: "client-certificate-mapper", Version: "2.0.1"}
			mockManifest.EXPECT().DefaultVersion("client-certificate-mapper").Return(depClientCertificateMapper, nil)
			depContainerSecProvider := libbuildpack.Dependency{Name: "container-security-provider", Version: "1.20.0"}
			mockManifest.EXPECT().DefaultVersion("container-security-provider").Return(depContainerSecProvider, nil)

			mockInstaller.EXPECT().InstallDependency(depClientCertificateMapper, ccmInstallDir).Return(nil)
			mockInstaller.EXPECT().InstallDependency(depContainerSecProvider, cspInstallDir).Return(nil)
		})

		Context("when a Tomcat application is present", func() {
			BeforeEach(func() {
				// Create WEB-INF directory
				webInfDir := filepath.Join(buildDir, "WEB-INF")
				Expect(os.MkdirAll(webInfDir, 0755)).To(Succeed())

				// Create tomcat installdirs, dependencies and mocks used during supply phase
				mockManifest.EXPECT().AllDependencyVersions("tomcat").Return([]string{"10.1.50"})
				tomcatInstallDir := filepath.Join(depsDir, depsIdx, "tomcat")
				Expect(os.MkdirAll(filepath.Join(tomcatInstallDir), 0755)).To(Succeed())

				depTomcat := libbuildpack.Dependency{Name: "tomcat", Version: "10.1.50"}
				mockInstaller.EXPECT().InstallDependencyWithStrip(depTomcat, tomcatInstallDir, 1).Return(nil)

				tomcatLifeCycleSupportInstallDir := filepath.Join(depsDir, depsIdx, "tomcat", "lib")
				Expect(os.MkdirAll(filepath.Join(tomcatLifeCycleSupportInstallDir), 0755)).To(Succeed())

				tomcatAccessLoggingSupportInstallDir := filepath.Join(depsDir, depsIdx, "tomcat", "lib")
				Expect(os.MkdirAll(filepath.Join(tomcatAccessLoggingSupportInstallDir), 0755)).To(Succeed())

				tomcatLoggingSupportInstallDir := filepath.Join(depsDir, depsIdx, "tomcat", "bin")
				Expect(os.MkdirAll(filepath.Join(tomcatLoggingSupportInstallDir), 0755)).To(Succeed())

				// Create mocks for the tomcat dependencies downloaded during supply
				depTomcatLifeCycleSupport := libbuildpack.Dependency{Name: "tomcat-lifecycle-support", Version: "3.4.0"}
				mockManifest.EXPECT().DefaultVersion("tomcat-lifecycle-support").Return(depTomcatLifeCycleSupport, nil)
				depTomcatAccessLoggingSupport := libbuildpack.Dependency{Name: "tomcat-access-logging-support", Version: "3.4.0"}
				mockManifest.EXPECT().DefaultVersion("tomcat-access-logging-support").Return(depTomcatAccessLoggingSupport, nil)
				depTomcatLoggingSupport := libbuildpack.Dependency{Name: "tomcat-logging-support", Version: "3.4.0"}
				mockManifest.EXPECT().DefaultVersion("tomcat-logging-support").Return(depTomcatLoggingSupport, nil)

				mockInstaller.EXPECT().InstallDependency(depTomcatLifeCycleSupport, tomcatLifeCycleSupportInstallDir).Return(nil)
				mockInstaller.EXPECT().InstallDependency(depTomcatAccessLoggingSupport, tomcatAccessLoggingSupportInstallDir).Return(nil)
				mockInstaller.EXPECT().InstallDependency(depTomcatLoggingSupport, tomcatLoggingSupportInstallDir).Return(nil)

				mockManifest.EXPECT().GetEntry(depTomcatLoggingSupport).Return(&libbuildpack.ManifestEntry{}, nil)
			})

			It("Supply passes successfully", func() {
				err := supply.Run(supplier)

				Expect(err).To(BeNil())
			})
		})

		Context("when a Spring-boot application is present", func() {
			BeforeEach(func() {
				// Create a Spring Boot JAR with BOOT-INF
				bootInfDir := filepath.Join(buildDir, "BOOT-INF")
				Expect(os.MkdirAll(bootInfDir, 0755)).To(Succeed())
				Expect(os.MkdirAll(filepath.Join(buildDir, "META-INF"), 0755)).To(Succeed())

				// Create META-INF/MANIFEST.MF with corresponding content of a Spring Boot app
				manifestFile := filepath.Join(buildDir, "META-INF", "MANIFEST.MF")
				Expect(os.WriteFile(manifestFile, []byte("Spring-Boot-Version: 3.x.x"), 0644)).To(Succeed())

				//Create install dir and mock for the java cf env spring boot related dependency
				javaCfEnvInstallDir := filepath.Join(depsDir, depsIdx, "java_cf_env")
				Expect(os.MkdirAll(filepath.Join(javaCfEnvInstallDir), 0755)).To(Succeed())

				depJavaCfEnv := libbuildpack.Dependency{Name: "java-cfenv", Version: "3.5.0"}
				mockManifest.EXPECT().DefaultVersion("java-cfenv").Return(depJavaCfEnv, nil)
				mockInstaller.EXPECT().InstallDependency(depJavaCfEnv, javaCfEnvInstallDir).Return(nil)
			})

			It("Supply passes successfully", func() {
				err := supply.Run(supplier)

				Expect(err).To(BeNil())
			})
		})

		Context("when a Groovy application is present", func() {
			BeforeEach(func() {
				// Create a .groovy file
				groovyFile := filepath.Join(buildDir, "app.groovy")
				Expect(os.WriteFile(groovyFile, []byte("println 'hello'"), 0644)).To(Succeed())

				//Create groovy install dir and dependency mock
				groovyInstallDir := filepath.Join(depsDir, depsIdx, "groovy")
				err := os.MkdirAll(filepath.Join(groovyInstallDir), 0755)
				Expect(err).To(BeNil())

				depGroovy := libbuildpack.Dependency{Name: "groovy", Version: "4.0.29"}
				mockManifest.EXPECT().DefaultVersion("groovy").Return(depGroovy, nil)
				mockInstaller.EXPECT().InstallDependencyWithStrip(depGroovy, groovyInstallDir, 1).Return(nil)
			})

			It("Supply passes successfully", func() {
				err := supply.Run(supplier)

				Expect(err).To(BeNil())
			})
		})
	})

	Describe("Stager Configuration", func() {
		It("creates necessary directories in deps dir", func() {
			depDir := stager.DepDir()
			Expect(depDir).To(ContainSubstring(depsDir))
		})

		It("has access to build directory", func() {
			Expect(stager.BuildDir()).To(Equal(buildDir))
		})

		It("has access to cache directory", func() {
			Expect(stager.CacheDir()).To(Equal(cacheDir))
		})
	})

	Describe("WriteConfigYml", func() {
		It("persists all supply phase keys in a single write", func() {
			// Verify that writing all keys at once means none are lost.
			// (WriteConfigYml always overwrites the file — writing twice drops the first set.)
			config := map[string]string{
				"container":   "spring-boot",
				"jre":         "OpenJDK",
				"jre_version": "17.0.9",
				"java_home":   "/deps/0/jre",
			}

			err := stager.WriteConfigYml(config)
			Expect(err).NotTo(HaveOccurred())

			// Read back and verify all keys are present
			raw := struct {
				Config map[string]string `yaml:"config"`
			}{}
			configPath := filepath.Join(stager.DepDir(), "config.yml")
			Expect(configPath).To(BeAnExistingFile())

			err = libbuildpack.NewYAML().Load(configPath, &raw)
			Expect(err).NotTo(HaveOccurred())
			Expect(raw.Config["container"]).To(Equal("spring-boot"))
			Expect(raw.Config["jre"]).To(Equal("OpenJDK"))
			Expect(raw.Config["jre_version"]).To(Equal("17.0.9"))
			Expect(raw.Config["java_home"]).To(Equal("/deps/0/jre"))
		})

		It("handles empty config gracefully", func() {
			err := stager.WriteConfigYml(nil)
			Expect(err).NotTo(HaveOccurred())
		})
	})
})
