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

func newYourKitContext(buildDir, cacheDir, depsDir string) *common.Context {
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

// installYourKitAgent creates the expected libyjpagent.so under depsDir at the linux-x86-64 path.
func installYourKitAgent(depsDir string) {
	libDir := filepath.Join(depsDir, "0", "your_kit_profiler", "bin", "linux-x86-64")
	Expect(os.MkdirAll(libDir, 0755)).To(Succeed())
	Expect(os.WriteFile(filepath.Join(libDir, "libyjpagent.so"), []byte("fake so"), 0644)).To(Succeed())
}

var _ = Describe("YourKitProfiler", func() {
	var (
		fw       *frameworks.YourKitProfilerFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "yk-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "yk-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "yk-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewYourKitProfilerFramework(newYourKitContext(buildDir, cacheDir, depsDir))
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(cacheDir)
		os.RemoveAll(depsDir)
		os.Unsetenv("JBP_CONFIG_YOUR_KIT_PROFILER")
	})

	Describe("Detect", func() {
		Context("with no environment set", func() {
			It("returns empty string (disabled by default)", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with JBP_CONFIG_YOUR_KIT_PROFILER set to 'enabled: true'", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_YOUR_KIT_PROFILER", "enabled: true")
			})

			It("returns 'YourKit Profiler'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("YourKit Profiler"))
			})
		})

		Context("with JBP_CONFIG_YOUR_KIT_PROFILER set to 'enabled: false'", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_YOUR_KIT_PROFILER", "enabled: false")
			})

			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with JBP_CONFIG_YOUR_KIT_PROFILER set to '{enabled: true}' (JSON-style)", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_YOUR_KIT_PROFILER", "{enabled: true}")
			})

			It("returns 'YourKit Profiler'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("YourKit Profiler"))
			})
		})

		Context("with JBP_CONFIG_YOUR_KIT_PROFILER containing 'ENABLED: TRUE' (uppercase)", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_YOUR_KIT_PROFILER", "ENABLED: TRUE")
			})

			It("returns 'YourKit Profiler' (case-insensitive match)", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("YourKit Profiler"))
			})
		})

		Context("with JBP_CONFIG_YOUR_KIT_PROFILER set to an unrelated value", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_YOUR_KIT_PROFILER", "port: 10001")
			})

			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})
	})

	Describe("Finalize", func() {
		Context("with agent library present at the linux-x86-64 path", func() {
			BeforeEach(func() {
				installYourKitAgent(depsDir)
			})

			It("writes the opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "45_your_kit_profiler.opts")).To(BeAnExistingFile())
			})

			It("opts file contains -agentpath pointing to the runtime libyjpagent.so", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "45_your_kit_profiler.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-agentpath:"))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/your_kit_profiler/bin/linux-x86-64/libyjpagent.so"))
			})

			It("opts file does not embed the staging-time absolute path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "45_your_kit_profiler.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(depsDir))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR"))
			})

			It("uses priority prefix 45 in the filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				entries, err := os.ReadDir(filepath.Join(depsDir, "0", "java_opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(entries).To(HaveLen(1))
				Expect(entries[0].Name()).To(Equal("45_your_kit_profiler.opts"))
			})

			It("opts file contains default port 10001", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "45_your_kit_profiler.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("port=10001"))
			})

			It("opts file contains dir and logdir pointing to $DEPS_DIR runtime path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "45_your_kit_profiler.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("dir=$DEPS_DIR/0/yourkit"))
				Expect(string(content)).To(ContainSubstring("logdir=$DEPS_DIR/0/yourkit"))
			})

			It("opts file contains sessionname option", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "45_your_kit_profiler.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("sessionname="))
			})

			It("creates the yourkit home directory", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "yourkit")).To(BeADirectory())
			})
		})

		Context("when the agent library is not present", func() {
			It("returns an error", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to locate yourkit agent"))
			})
		})

		Context("when only the ARM64 library is present (no linux-x86-64)", func() {
			BeforeEach(func() {
				armDir := filepath.Join(depsDir, "0", "your_kit_profiler", "bin", "linux-aarch64")
				Expect(os.MkdirAll(armDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(armDir, "libyjpagent.so"), []byte("fake so"), 0644)).To(Succeed())
			})

			It("returns an error (arch filter excludes non-x86-64)", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to locate yourkit agent"))
			})
		})
	})
})
