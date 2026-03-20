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

var _ = Describe("Spring Boot Container", func() {
	var (
		ctx       *common.Context
		container *containers.SpringBootContainer
		buildDir  string
		depsDir   string
		cacheDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "build")
		Expect(err).NotTo(HaveOccurred())

		depsDir, err = os.MkdirTemp("", "deps")
		Expect(err).NotTo(HaveOccurred())

		cacheDir, err = os.MkdirTemp("", "cache")
		Expect(err).NotTo(HaveOccurred())

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

		container = containers.NewSpringBootContainer(ctx)
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(depsDir)
		os.RemoveAll(cacheDir)
	})

	Describe("Detect", func() {
		Context("with BOOT-INF directory", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "BOOT-INF"), 0755)
				os.MkdirAll(filepath.Join(buildDir, "META-INF"), 0755)
				manifest := "Manifest-Version: 1.0\nStart-Class: com.example.App\nSpring-Boot-Version: 2.7.0\n"
				os.WriteFile(filepath.Join(buildDir, "META-INF", "MANIFEST.MF"), []byte(manifest), 0644)
			})

			It("detects as Spring Boot", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Spring Boot"))
			})
		})

		Context("without Spring Boot indicators", func() {
			It("does not detect as Spring Boot", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with spring-boot.jar", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "spring-boot.jar"), []byte("fake jar"), 0644)
			})

			It("detects as Spring Boot", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Spring Boot"))
			})
		})

		Context("with myapp-boot.jar", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "myapp-boot.jar"), []byte("fake jar"), 0644)
			})

			It("detects as Spring Boot", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Spring Boot"))
			})
		})

		Context("with non-Spring Boot JAR", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "regular.jar"), []byte("fake jar"), 0644)
			})

			It("does not detect as Spring Boot", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})
	})

	Describe("Release", func() {
		Context("with exploded JAR (BOOT-INF)", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "BOOT-INF"), 0755)
				os.MkdirAll(filepath.Join(buildDir, "META-INF"), 0755)
				manifest := "Manifest-Version: 1.0\nMain-Class: org.springframework.boot.loader.JarLauncher\nStart-Class: com.example.App\nSpring-Boot-Version: 2.7.0\n"
				os.WriteFile(filepath.Join(buildDir, "META-INF", "MANIFEST.MF"), []byte(manifest), 0644)
				container.Detect()
			})

			It("uses JarLauncher", func() {
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(ContainSubstring("JarLauncher"))
			})
		})

		Context("with Spring Boot JAR", func() {
			BeforeEach(func() {
				jarPath := filepath.Join(buildDir, "app-boot.jar")
				os.WriteFile(jarPath, []byte("fake jar content"), 0644)
				container.Detect()
			})

			It("uses java -jar", func() {
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(ContainSubstring("java"))
				Expect(cmd).To(ContainSubstring("app-boot.jar"))
			})
		})

		Context("with no Spring Boot JAR found", func() {
			It("returns error", func() {
				_, err := container.Release()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no Spring Boot JAR"))
			})
		})
	})

	Describe("Finalize", func() {
		BeforeEach(func() {
			os.WriteFile(filepath.Join(buildDir, "spring-boot.jar"), []byte("fake"), 0644)
			container.Detect()
		})

		It("finalizes successfully", func() {
			err := container.Finalize()
			Expect(err).NotTo(HaveOccurred())
		})
	})
})
