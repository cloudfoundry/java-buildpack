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

func newJRebelContext(buildDir, cacheDir, depsDir string) *common.Context {
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

var _ = Describe("JRebel Agent", func() {
	var (
		fw       *frameworks.JRebelAgentFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "jrebel-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "jrebel-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "jrebel-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewJRebelAgentFramework(newJRebelContext(buildDir, cacheDir, depsDir))
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(cacheDir)
		os.RemoveAll(depsDir)
		os.Unsetenv("JBP_CONFIG_JREBEL")
	})

	Describe("Detect", func() {
		Context("with rebel-remote.xml at the build root", func() {
			BeforeEach(func() {
				Expect(os.WriteFile(filepath.Join(buildDir, "rebel-remote.xml"), []byte("<rebel/>"), 0644)).To(Succeed())
			})

			It("returns 'jrebel'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("jrebel"))
			})
		})

		Context("with rebel-remote.xml in WEB-INF", func() {
			BeforeEach(func() {
				Expect(os.MkdirAll(filepath.Join(buildDir, "WEB-INF"), 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(buildDir, "WEB-INF", "rebel-remote.xml"), []byte("<rebel/>"), 0644)).To(Succeed())
			})

			It("returns 'jrebel'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("jrebel"))
			})
		})

		Context("with no rebel-remote.xml present", func() {
			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with rebel-remote.xml present but disabled via JBP_CONFIG_JREBEL", func() {
			BeforeEach(func() {
				Expect(os.WriteFile(filepath.Join(buildDir, "rebel-remote.xml"), []byte("<rebel/>"), 0644)).To(Succeed())
				os.Setenv("JBP_CONFIG_JREBEL", "enabled: false")
			})

			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with rebel-remote.xml present and explicitly enabled via JBP_CONFIG_JREBEL", func() {
			BeforeEach(func() {
				Expect(os.WriteFile(filepath.Join(buildDir, "rebel-remote.xml"), []byte("<rebel/>"), 0644)).To(Succeed())
				os.Setenv("JBP_CONFIG_JREBEL", "enabled: true")
			})

			It("returns 'jrebel'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("jrebel"))
			})
		})

		Context("with no config set (default enabled)", func() {
			BeforeEach(func() {
				Expect(os.WriteFile(filepath.Join(buildDir, "rebel-remote.xml"), []byte("<rebel/>"), 0644)).To(Succeed())
			})

			It("is enabled by default", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("jrebel"))
			})
		})
	})

	Describe("Finalize", func() {
		Context("with the agent library at the nested path (jrebel/jrebel/lib/libjrebel64.so)", func() {
			BeforeEach(func() {
				libPath := filepath.Join(depsDir, "0", "jrebel", "jrebel", "lib")
				Expect(os.MkdirAll(libPath, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(libPath, "libjrebel64.so"), []byte("fake"), 0644)).To(Succeed())
			})

			It("writes the opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "31_jrebel.opts")).To(BeAnExistingFile())
			})

			It("opts file contains -agentpath pointing to the nested runtime path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "31_jrebel.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-agentpath:"))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/jrebel/jrebel/lib/libjrebel64.so"))
			})
		})

		Context("with the agent library at the flat path (jrebel/lib/libjrebel64.so)", func() {
			BeforeEach(func() {
				libPath := filepath.Join(depsDir, "0", "jrebel", "lib")
				Expect(os.MkdirAll(libPath, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(libPath, "libjrebel64.so"), []byte("fake"), 0644)).To(Succeed())
			})

			It("writes the opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "31_jrebel.opts")).To(BeAnExistingFile())
			})

			It("opts file references the flat runtime path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "31_jrebel.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/jrebel/lib/libjrebel64.so"))
			})
		})

		Context("with the agent library at the root of the jrebel dir (jrebel/libjrebel64.so)", func() {
			BeforeEach(func() {
				jrebelDir := filepath.Join(depsDir, "0", "jrebel")
				Expect(os.MkdirAll(jrebelDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(jrebelDir, "libjrebel64.so"), []byte("fake"), 0644)).To(Succeed())
			})

			It("writes the opts file with the root-level runtime path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "31_jrebel.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/jrebel/libjrebel64.so"))
			})
		})

		Context("when the agent library is not present", func() {
			It("succeeds without writing an opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "31_jrebel.opts")).NotTo(BeAnExistingFile())
			})
		})

		Context("opts file naming and priority", func() {
			BeforeEach(func() {
				libPath := filepath.Join(depsDir, "0", "jrebel", "lib")
				Expect(os.MkdirAll(libPath, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(libPath, "libjrebel64.so"), []byte("fake"), 0644)).To(Succeed())
			})

			It("uses priority prefix 31 in the filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				entries, err := os.ReadDir(filepath.Join(depsDir, "0", "java_opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(entries).To(HaveLen(1))
				Expect(entries[0].Name()).To(Equal("31_jrebel.opts"))
			})
		})

		Context("opts file uses $DEPS_DIR for runtime portability", func() {
			BeforeEach(func() {
				libPath := filepath.Join(depsDir, "0", "jrebel", "lib")
				Expect(os.MkdirAll(libPath, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(libPath, "libjrebel64.so"), []byte("fake"), 0644)).To(Succeed())
			})

			It("does not embed the staging-time absolute path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "31_jrebel.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(depsDir))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR"))
			})
		})
	})
})
