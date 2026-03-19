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

var _ = Describe("Groovy Container", func() {
	var (
		ctx       *common.Context
		container *containers.GroovyContainer
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

		container = containers.NewGroovyContainer(ctx)
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(depsDir)
		os.RemoveAll(cacheDir)
	})

	Describe("Detect", func() {
		Context("with .groovy files", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "app.groovy"), []byte("println 'hello'"), 0644)
			})

			It("detects as Groovy", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Groovy"))
			})
		})

		Context("with multiple .groovy files", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "app.groovy"), []byte("println 'app'"), 0644)
				os.WriteFile(filepath.Join(buildDir, "util.groovy"), []byte("println 'util'"), 0644)
				os.WriteFile(filepath.Join(buildDir, "main.groovy"), []byte("println 'main'"), 0644)
			})

			It("detects as Groovy", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Groovy"))
			})
		})

		Context("with .groovy in src/", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "src"), 0755)
				os.WriteFile(filepath.Join(buildDir, "src", "app.groovy"), []byte("println 'app'"), 0644)
			})

			It("does not detect (only checks root)", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})
	})

	Describe("Release", func() {
		Context("with GROOVY_SCRIPT environment variable", func() {
			BeforeEach(func() {
				os.Setenv("GROOVY_SCRIPT", "custom.groovy")
				os.WriteFile(filepath.Join(buildDir, "app.groovy"), []byte("println 'app'"), 0644)
				container.Detect()
			})

			AfterEach(func() {
				os.Unsetenv("GROOVY_SCRIPT")
			})

			It("uses the specified script", func() {
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(ContainSubstring("groovy"))
				Expect(cmd).To(ContainSubstring("custom.groovy"))
			})
		})

		Context("with detected Groovy scripts", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "app.groovy"), []byte("println 'app'"), 0644)
				os.WriteFile(filepath.Join(buildDir, "util.groovy"), []byte("println 'util'"), 0644)
				container.Detect()
			})

			It("uses the first script found", func() {
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(ContainSubstring("groovy"))
				Expect(cmd).To(MatchRegexp("(app|util)\\.groovy"))
			})
		})

		Context("with no script available", func() {
			It("returns error", func() {
				_, err := container.Release()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no Groovy script specified"))
			})
		})

		Context("with lib JARs in the build directory", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "app.groovy"), []byte("println 'app'"), 0644)
				os.MkdirAll(filepath.Join(buildDir, "lib"), 0755)
				os.WriteFile(filepath.Join(buildDir, "lib", "mylib.jar"), []byte(""), 0644)
				os.WriteFile(filepath.Join(buildDir, "lib", "other.jar"), []byte(""), 0644)
				container.Detect()
			})

			It("includes lib JARs in the classpath via -cp flag", func() {
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(ContainSubstring("-cp "))
				Expect(cmd).To(ContainSubstring("$HOME/lib/mylib.jar"))
				Expect(cmd).To(ContainSubstring("$HOME/lib/other.jar"))
				Expect(cmd).To(ContainSubstring("${CLASSPATH:+:$CLASSPATH}${CONTAINER_SECURITY_PROVIDER:+:$CONTAINER_SECURITY_PROVIDER}"))
			})

			It("places the -cp flag before the script name", func() {
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(MatchRegexp(`-cp .+ app\.groovy$`))
			})
		})

		Context("with no JARs anywhere", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "app.groovy"), []byte("println 'app'"), 0644)
				container.Detect()
			})

			It("omits the -cp flag", func() {
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(Equal("$GROOVY_HOME/bin/groovy -cp ${CLASSPATH:+:$CLASSPATH}${CONTAINER_SECURITY_PROVIDER:+:$CONTAINER_SECURITY_PROVIDER} app.groovy"))
			})
		})
	})

	Describe("Finalize", func() {
		BeforeEach(func() {
			os.WriteFile(filepath.Join(buildDir, "app.groovy"), []byte("println 'test'"), 0644)
			container.Detect()
		})

		It("finalizes successfully", func() {
			err := container.Finalize()
			Expect(err).NotTo(HaveOccurred())
		})
	})
})
