package finalize_test

import (
	"github.com/cloudfoundry/java-buildpack/src/internal/mocks"
	"github.com/golang/mock/gomock"
	"os"
	"path/filepath"
	"time"

	"github.com/cloudfoundry/java-buildpack/src/java/finalize"
	"github.com/cloudfoundry/libbuildpack"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Finalize", func() {
	var (
		buildDir      string
		cacheDir      string
		depsDir       string
		depsIdx       string
		stager        *libbuildpack.Stager
		mockCtrl      *gomock.Controller
		mockManifest  *mocks.MockManifest
		mockInstaller *mocks.MockInstaller
		finalizer     *finalize.Finalizer
		logger        *libbuildpack.Logger
	)

	BeforeEach(func() {
		var err error

		buildDir, err = os.MkdirTemp("", "finalize-build")
		Expect(err).NotTo(HaveOccurred())

		cacheDir, err = os.MkdirTemp("", "finalize-cache")
		Expect(err).NotTo(HaveOccurred())

		depsDir, err = os.MkdirTemp("", "finalize-deps")
		Expect(err).NotTo(HaveOccurred())

		depsIdx = "0"

		buildpackDir, err := os.MkdirTemp("", "finalize-buildpack")
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

		logger = libbuildpack.NewLogger(GinkgoWriter)

		mockCtrl = gomock.NewController(GinkgoT())
		mockManifest = mocks.NewMockManifest(mockCtrl)
		mockInstaller = mocks.NewMockInstaller(mockCtrl)

		manifest, err := libbuildpack.NewManifest(buildpackDir, logger, time.Now())
		Expect(err).NotTo(HaveOccurred())

		stager = libbuildpack.NewStager([]string{buildDir, cacheDir, depsDir, depsIdx}, logger, manifest)

		finalizer = &finalize.Finalizer{
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

	Describe("Various Container Finalize", func() {
		Context("When a Spring Boot application is present", func() {
			BeforeEach(func() {
				// Create a Spring Boot JAR with BOOT-INF
				bootInfDir := filepath.Join(buildDir, "BOOT-INF")
				Expect(os.MkdirAll(bootInfDir, 0755)).To(Succeed())
				Expect(os.MkdirAll(filepath.Join(buildDir, "META-INF"), 0755)).To(Succeed())

				// Create META-INF/MANIFEST.MF with corresponding content of a Spring Boot app
				manifestFile := filepath.Join(buildDir, "META-INF", "MANIFEST.MF")
				Expect(os.WriteFile(manifestFile, []byte("Spring-Boot-Version: 3.x.x"), 0644)).To(Succeed())

				finalizer.JREName = "OpenJDK"
				finalizer.ContainerName = "Spring Boot"
			})

			It("Finalize passes successfully", func() {
				Expect(finalize.Run(finalizer)).To(Succeed())
			})
		})

		Context("When a Tomcat application is present", func() {
			BeforeEach(func() {
				webInfDir := filepath.Join(buildDir, "WEB-INF")
				Expect(os.MkdirAll(webInfDir, 0755)).To(Succeed())

				finalizer.JREName = "OpenJDK"
				finalizer.ContainerName = "Tomcat"
			})

			It("Finalize passes successfully", func() {
				Expect(finalize.Run(finalizer)).To(Succeed())
			})
		})

		Context("When a Groovy application is present", func() {
			BeforeEach(func() {
				// Create a .groovy file
				groovyFile := filepath.Join(buildDir, "app.groovy")
				Expect(os.WriteFile(groovyFile, []byte("println 'hello'"), 0644)).To(Succeed())

				finalizer.JREName = "OpenJDK"
				finalizer.ContainerName = "Groovy"
			})

			It("Finalize passes successfully", func() {
				Expect(finalize.Run(finalizer)).To(Succeed())
			})
		})
	})

	Describe("Startup Script Generation", func() {
		It("creates .java-buildpack directory", func() {
			javaBuildpackDir := filepath.Join(buildDir, ".java-buildpack")
			Expect(os.MkdirAll(javaBuildpackDir, 0755)).To(Succeed())
			Expect(javaBuildpackDir).To(BeADirectory())
		})

		It("would generate start.sh in .java-buildpack directory", func() {
			javaBuildpackDir := filepath.Join(buildDir, ".java-buildpack")
			Expect(os.MkdirAll(javaBuildpackDir, 0755)).To(Succeed())

			startScript := filepath.Join(javaBuildpackDir, "start.sh")
			Expect(filepath.Dir(startScript)).To(Equal(javaBuildpackDir))
		})
	})

	Describe("Environment Setup", func() {
		It("has access to deps directory for environment files", func() {
			depDir := stager.DepDir()
			envDir := filepath.Join(depDir, "env")
			Expect(os.MkdirAll(envDir, 0755)).To(Succeed())
			Expect(envDir).To(BeADirectory())
		})

		It("can write environment variables to env directory", func() {
			depDir := stager.DepDir()
			envDir := filepath.Join(depDir, "env")
			Expect(os.MkdirAll(envDir, 0755)).To(Succeed())

			javaHomeFile := filepath.Join(envDir, "JAVA_HOME")
			Expect(os.WriteFile(javaHomeFile, []byte("/deps/0/jre"), 0644)).To(Succeed())
			Expect(javaHomeFile).To(BeAnExistingFile())
		})
	})

	Describe("Profile.d Script Creation", func() {
		It("can create profile.d directory in build dir", func() {
			profileDir := filepath.Join(buildDir, ".profile.d")
			Expect(os.MkdirAll(profileDir, 0755)).To(Succeed())
			Expect(profileDir).To(BeADirectory())
		})

		It("can write profile.d scripts", func() {
			profileDir := filepath.Join(buildDir, ".profile.d")
			Expect(os.MkdirAll(profileDir, 0755)).To(Succeed())

			javaScript := filepath.Join(profileDir, "java.sh")
			scriptContent := "export JAVA_HOME=$DEPS_DIR/" + depsIdx + "/jre\n"
			Expect(os.WriteFile(javaScript, []byte(scriptContent), 0755)).To(Succeed())
			Expect(javaScript).To(BeAnExistingFile())
		})
	})

	Describe("Config Persistence", func() {
		It("NewFinalizer reads all keys written by the supply phase", func() {
			// Simulate what supply phase writes: all keys in a single call
			config := map[string]string{
				"container":   "spring-boot",
				"jre":         "OpenJDK",
				"jre_version": "17.0.9",
				"java_home":   "/deps/0/jre",
			}
			err := stager.WriteConfigYml(config)
			Expect(err).NotTo(HaveOccurred())

			// NewFinalizer must successfully read the config.yml written above
			f, err := finalize.NewFinalizer(stager, mockManifest, mockInstaller, logger, &libbuildpack.Command{})
			Expect(err).NotTo(HaveOccurred())
			Expect(f.ContainerName).To(Equal("spring-boot"))
			Expect(f.JREName).To(Equal("OpenJDK"))
		})

		It("NewFinalizer fails when config.yml is missing", func() {
			// No config.yml written — NewFinalizer must return an error
			_, err := finalize.NewFinalizer(stager, mockManifest, mockInstaller, logger, &libbuildpack.Command{})
			Expect(err).To(HaveOccurred())
		})

		It("NewFinalizer fails when required keys are absent", func() {
			// Write config with empty map — container and jre keys missing
			err := stager.WriteConfigYml(map[string]string{})
			Expect(err).NotTo(HaveOccurred())

			_, err = finalize.NewFinalizer(stager, mockManifest, mockInstaller, logger, &libbuildpack.Command{})
			Expect(err).To(HaveOccurred())
		})
	})

	Describe("Stager Configuration", func() {
		It("has access to build directory", func() {
			Expect(stager.BuildDir()).To(Equal(buildDir))
		})

		It("has access to cache directory", func() {
			Expect(stager.CacheDir()).To(Equal(cacheDir))
		})

		It("has access to deps directory", func() {
			depDir := stager.DepDir()
			Expect(depDir).To(ContainSubstring(depsDir))
		})
	})
})
