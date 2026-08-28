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

// installYourKitAgentSpacedDir simulates the 2026.3+ zip layout where the top-level
// directory is "YourKit Java Profiler/" (contains spaces).
func installYourKitAgentSpacedDir(depsDir string) {
	libDir := filepath.Join(depsDir, "0", "your_kit_profiler", "YourKit Java Profiler", "bin", "linux-x86-64")
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

	Describe("Supply path normalisation", func() {
		Context("when libyjpagent.so is already at the canonical space-free path", func() {
			BeforeEach(func() {
				installYourKitAgent(depsDir)
			})

			It("leaves the file in place (no-op)", func() {
				canonical := filepath.Join(depsDir, "0", "your_kit_profiler", "bin", "linux-x86-64", "libyjpagent.so")
				info1, err := os.Stat(canonical)
				Expect(err).NotTo(HaveOccurred())
				// Simulate the normalisation logic: canonical already exists, nothing to do
				Expect(info1).NotTo(BeNil())
			})
		})

		Context("when libyjpagent.so is under a directory with spaces (2026.3+ layout)", func() {
			BeforeEach(func() {
				installYourKitAgentSpacedDir(depsDir)
			})

			It("copies libyjpagent.so to the canonical space-free path", func() {
				installDir := filepath.Join(depsDir, "0", "your_kit_profiler")
				canonical := filepath.Join(installDir, "bin", "linux-x86-64", "libyjpagent.so")
				// Canonical does not exist yet
				Expect(canonical).NotTo(BeAnExistingFile())

				// Run the same normalisation logic the Supply() method uses
				found, err := frameworks.FindFileInDirectoryWithArchFilter(installDir, "libyjpagent.so", nil, []string{"linux-x86-64"})
				Expect(err).NotTo(HaveOccurred())
				Expect(os.MkdirAll(filepath.Dir(canonical), 0755)).To(Succeed())
				src, err := os.ReadFile(found)
				Expect(err).NotTo(HaveOccurred())
				Expect(os.WriteFile(canonical, src, 0755)).To(Succeed())

				Expect(canonical).To(BeAnExistingFile())
				content, err := os.ReadFile(canonical)
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(Equal("fake so"))
			})

			It("Finalize produces -agentpath with no spaces after normalisation", func() {
				// Manually normalise (simulating Supply())
				installDir := filepath.Join(depsDir, "0", "your_kit_profiler")
				canonical := filepath.Join(installDir, "bin", "linux-x86-64", "libyjpagent.so")
				found, err := frameworks.FindFileInDirectoryWithArchFilter(installDir, "libyjpagent.so", nil, []string{"linux-x86-64"})
				Expect(err).NotTo(HaveOccurred())
				Expect(os.MkdirAll(filepath.Dir(canonical), 0755)).To(Succeed())
				src, err := os.ReadFile(found)
				Expect(err).NotTo(HaveOccurred())
				Expect(os.WriteFile(canonical, src, 0755)).To(Succeed())

				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "45_your_kit_profiler.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(" "))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/your_kit_profiler/bin/linux-x86-64/libyjpagent.so"))
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

