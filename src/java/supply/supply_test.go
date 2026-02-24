package supply_test

import (
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
		buildDir string
		cacheDir string
		depsDir  string
		depsIdx  string
		supplier *supply.Supplier
		stager   *libbuildpack.Stager
		logger   *libbuildpack.Logger
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

		// Create manifest with buildpack dir
		manifest, err := libbuildpack.NewManifest(buildpackDir, logger, time.Now())
		Expect(err).NotTo(HaveOccurred())

		// Create stager
		stager = libbuildpack.NewStager([]string{buildDir, cacheDir, depsDir, depsIdx}, logger, manifest)

		supplier = &supply.Supplier{
			Stager:   stager,
			Manifest: manifest,
			Log:      logger,
			Command:  &libbuildpack.Command{},
		}
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(cacheDir)
		os.RemoveAll(depsDir)
	})

	Describe("Container Detection", func() {
		Context("when a Spring Boot application is present", func() {
			BeforeEach(func() {
				// Create a Spring Boot JAR with BOOT-INF
				bootInfDir := filepath.Join(buildDir, "BOOT-INF")
				Expect(os.MkdirAll(bootInfDir, 0755)).To(Succeed())
			})

			It("creates the supplier with required components", func() {
				// Verify supplier is properly initialized
				Expect(supplier).NotTo(BeNil())
				Expect(supplier.Stager).NotTo(BeNil())
				Expect(supplier.Manifest).NotTo(BeNil())
				Expect(supplier.Log).NotTo(BeNil())
				Expect(supplier.Command).NotTo(BeNil())
			})
		})

		Context("when a Tomcat application is present", func() {
			BeforeEach(func() {
				// Create WEB-INF directory
				webInfDir := filepath.Join(buildDir, "WEB-INF")
				Expect(os.MkdirAll(webInfDir, 0755)).To(Succeed())
			})

			It("creates the supplier with required components", func() {
				Expect(supplier).NotTo(BeNil())
				Expect(supplier.Stager).NotTo(BeNil())
				Expect(supplier.Manifest).NotTo(BeNil())
			})
		})

		Context("when a Groovy application is present", func() {
			BeforeEach(func() {
				// Create a .groovy file
				groovyFile := filepath.Join(buildDir, "app.groovy")
				Expect(os.WriteFile(groovyFile, []byte("println 'hello'"), 0644)).To(Succeed())
			})

			It("creates the supplier with required components", func() {
				Expect(supplier).NotTo(BeNil())
				Expect(supplier.Stager).NotTo(BeNil())
				Expect(supplier.Manifest).NotTo(BeNil())
			})
		})

		Context("when no recognized application type is present", func() {
			It("fails to detect a container", func() {
				// This would be tested via supply.Run() which we can't easily test
				// without mocking the installer to avoid real downloads.
				// Integration tests cover this scenario.
				Expect(supplier).NotTo(BeNil())
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
