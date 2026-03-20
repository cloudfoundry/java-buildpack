package containers_test

import (
	"os"
	"path/filepath"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/containers"
	"github.com/cloudfoundry/libbuildpack"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Container Registry", func() {
	var (
		ctx      *common.Context
		registry *containers.Registry
		buildDir string
		depsDir  string
		cacheDir string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "build")
		Expect(err).NotTo(HaveOccurred())

		depsDir, err = os.MkdirTemp("", "deps")
		Expect(err).NotTo(HaveOccurred())

		cacheDir, err = os.MkdirTemp("", "cache")
		Expect(err).NotTo(HaveOccurred())

		// Create deps directory structure
		err = os.MkdirAll(filepath.Join(depsDir, "0"), 0755)
		Expect(err).NotTo(HaveOccurred())

		logger := libbuildpack.NewLogger(os.Stdout)
		manifest := &libbuildpack.Manifest{}
		installer := &libbuildpack.Installer{}
		stager := libbuildpack.NewStager([]string{buildDir, cacheDir, depsDir, "0"}, logger, manifest)
		command := &libbuildpack.Command{}

		ctx = &common.Context{
			Stager:    stager,
			Manifest:  manifest,
			Installer: installer,
			Log:       logger,
			Command:   command,
		}

		registry = containers.NewRegistry(ctx)
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(depsDir)
		os.RemoveAll(cacheDir)
	})

	Describe("Registry", func() {
		BeforeEach(func() {
			registry.Register(containers.NewSpringBootContainer(ctx))
			registry.Register(containers.NewTomcatContainer(ctx))
			registry.Register(containers.NewGroovyContainer(ctx))
			registry.Register(containers.NewDistZipContainer(ctx))
			registry.Register(containers.NewJavaMainContainer(ctx))
		})

		Context("with Spring Boot app", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "BOOT-INF"), 0755)
				// Create META-INF/MANIFEST.MF with Spring Boot markers
				os.MkdirAll(filepath.Join(buildDir, "META-INF"), 0755)
				manifest := "Manifest-Version: 1.0\nStart-Class: com.example.App\nSpring-Boot-Version: 2.7.0\n"
				os.WriteFile(filepath.Join(buildDir, "META-INF", "MANIFEST.MF"), []byte(manifest), 0644)
			})

			It("detects Spring Boot container", func() {
				container, name, err := registry.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(container).NotTo(BeNil())
				Expect(name).To(Equal("Spring Boot"))
			})
		})

		Context("with no detectable app", func() {
			It("returns nil container", func() {
				container, name, err := registry.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(container).To(BeNil())
				Expect(name).To(BeEmpty())
			})
		})
	})

	Describe("DetectAll", func() {
		It("returns all matching containers", func() {
			// Create both Groovy and Tomcat (overlapping detection)
			os.WriteFile(filepath.Join(buildDir, "app.groovy"), []byte("println 'hello'"), 0644)
			os.MkdirAll(filepath.Join(buildDir, "WEB-INF"), 0755)

			registry := containers.NewRegistry(ctx)
			registry.Register(containers.NewGroovyContainer(ctx))
			registry.Register(containers.NewTomcatContainer(ctx))
			registry.Register(containers.NewJavaMainContainer(ctx))

			detected, names, err := registry.DetectAll()
			Expect(err).NotTo(HaveOccurred())
			Expect(len(detected)).To(Equal(2))
			Expect(len(names)).To(Equal(2))
			Expect(names).To(ContainElement("Groovy"))
			Expect(names).To(ContainElement("Tomcat"))
		})

		It("returns empty when no containers match", func() {
			registry := containers.NewRegistry(ctx)
			registry.Register(containers.NewSpringBootContainer(ctx))
			registry.Register(containers.NewTomcatContainer(ctx))

			detected, names, err := registry.DetectAll()
			Expect(err).NotTo(HaveOccurred())
			Expect(len(detected)).To(Equal(0))
			Expect(len(names)).To(Equal(0))
		})
	})

})
