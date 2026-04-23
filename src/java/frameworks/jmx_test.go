package frameworks_test

import (
	"fmt"
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/frameworks"
	"github.com/cloudfoundry/libbuildpack"
)

func newJmxContext(buildDir, cacheDir, depsDir string) *common.Context {
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

var _ = Describe("JMX", func() {
	var (
		fw       *frameworks.JmxFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "jmx-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "jmx-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "jmx-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewJmxFramework(newJmxContext(buildDir, cacheDir, depsDir))
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(cacheDir)
		os.RemoveAll(depsDir)
		os.Unsetenv("BPL_JMX_ENABLED")
		os.Unsetenv("BPL_JMX_PORT")
		os.Unsetenv("JBP_CONFIG_JMX")
	})

	Describe("Detect", func() {
		Context("with no configuration (default)", func() {
			It("returns empty string (disabled by default)", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with BPL_JMX_ENABLED=true", func() {
			BeforeEach(func() {
				os.Setenv("BPL_JMX_ENABLED", "true")
			})

			It("returns 'JMX'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("JMX"))
			})
		})

		Context("with BPL_JMX_ENABLED=1", func() {
			BeforeEach(func() {
				os.Setenv("BPL_JMX_ENABLED", "1")
			})

			It("returns 'JMX'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("JMX"))
			})
		})

		Context("with BPL_JMX_ENABLED=false", func() {
			BeforeEach(func() {
				os.Setenv("BPL_JMX_ENABLED", "false")
			})

			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with BPL_JMX_ENABLED=0", func() {
			BeforeEach(func() {
				os.Setenv("BPL_JMX_ENABLED", "0")
			})

			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with JBP_CONFIG_JMX enabled: true", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_JMX", "enabled: true")
			})

			It("returns 'JMX'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("JMX"))
			})
		})

		Context("with JBP_CONFIG_JMX enabled: false", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_JMX", "enabled: false")
			})

			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("when BPL_JMX_ENABLED overrides JBP_CONFIG_JMX", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_JMX", "enabled: false")
				os.Setenv("BPL_JMX_ENABLED", "true")
			})

			It("BPL_JMX_ENABLED takes precedence — returns 'JMX'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("JMX"))
			})
		})

		Context("when BPL_JMX_ENABLED=false overrides JBP_CONFIG_JMX enabled: true", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_JMX", "enabled: true")
				os.Setenv("BPL_JMX_ENABLED", "false")
			})

			It("BPL_JMX_ENABLED takes precedence — returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})
	})

	Describe("Finalize", func() {
		Context("with default port (5000)", func() {
			BeforeEach(func() {
				os.Setenv("BPL_JMX_ENABLED", "true")
			})

			It("writes the opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "29_jmx.opts")).To(BeAnExistingFile())
			})

			It("opts file contains the default port 5000", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "29_jmx.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcom.sun.management.jmxremote.port=5000"))
				Expect(string(content)).To(ContainSubstring("-Dcom.sun.management.jmxremote.rmi.port=5000"))
			})

			It("opts file disables authentication and SSL", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "29_jmx.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcom.sun.management.jmxremote.authenticate=false"))
				Expect(string(content)).To(ContainSubstring("-Dcom.sun.management.jmxremote.ssl=false"))
			})

			It("opts file sets RMI hostname to 127.0.0.1", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "29_jmx.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Djava.rmi.server.hostname=127.0.0.1"))
			})
		})

		Context("with BPL_JMX_PORT set", func() {
			BeforeEach(func() {
				os.Setenv("BPL_JMX_ENABLED", "true")
				os.Setenv("BPL_JMX_PORT", "9090")
			})

			It("uses the port from BPL_JMX_PORT", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "29_jmx.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcom.sun.management.jmxremote.port=9090"))
				Expect(string(content)).To(ContainSubstring("-Dcom.sun.management.jmxremote.rmi.port=9090"))
			})
		})

		Context("with port set via JBP_CONFIG_JMX", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_JMX", "enabled: true\nport: 7777")
			})

			It("uses the port from JBP_CONFIG_JMX", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "29_jmx.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcom.sun.management.jmxremote.port=7777"))
				Expect(string(content)).To(ContainSubstring("-Dcom.sun.management.jmxremote.rmi.port=7777"))
			})
		})

		Context("when BPL_JMX_PORT overrides JBP_CONFIG_JMX port", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_JMX", "enabled: true\nport: 7777")
				os.Setenv("BPL_JMX_PORT", "8888")
			})

			It("BPL_JMX_PORT takes precedence", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "29_jmx.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring(fmt.Sprintf("-Dcom.sun.management.jmxremote.port=%d", 8888)))
				Expect(string(content)).NotTo(ContainSubstring("7777"))
			})
		})

		Context("with an invalid BPL_JMX_PORT value", func() {
			BeforeEach(func() {
				os.Setenv("BPL_JMX_ENABLED", "true")
				os.Setenv("BPL_JMX_PORT", "not-a-number")
			})

			It("falls back to the default port 5000", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "29_jmx.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcom.sun.management.jmxremote.port=5000"))
			})
		})

		Context("opts file naming and priority", func() {
			BeforeEach(func() {
				os.Setenv("BPL_JMX_ENABLED", "true")
			})

			It("uses priority prefix 29 in the filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				optsDir := filepath.Join(depsDir, "0", "java_opts")
				entries, err := os.ReadDir(optsDir)
				Expect(err).NotTo(HaveOccurred())
				Expect(entries).To(HaveLen(1))
				Expect(entries[0].Name()).To(Equal("29_jmx.opts"))
			})
		})
	})
})
