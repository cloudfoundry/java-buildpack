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

func newMetricWriterContext(buildDir, cacheDir, depsDir string) *common.Context {
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

var _ = Describe("MetricWriter", func() {
	var (
		fw       *frameworks.MetricWriterFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "mw-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "mw-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "mw-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewMetricWriterFramework(newMetricWriterContext(buildDir, cacheDir, depsDir))
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(cacheDir)
		os.RemoveAll(depsDir)
		os.Unsetenv("JBP_CONFIG_METRIC_WRITER")
	})

	Describe("Detect", func() {
		Context("with no configuration (default disabled)", func() {
			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with JBP_CONFIG_METRIC_WRITER enabled: false", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_METRIC_WRITER", "enabled: false")
				libDir := filepath.Join(buildDir, "BOOT-INF", "lib")
				Expect(os.MkdirAll(libDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(libDir, "micrometer-core-1.12.0.jar"), []byte("fake"), 0644)).To(Succeed())
			})

			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with JBP_CONFIG_METRIC_WRITER enabled: true and micrometer in BOOT-INF/lib", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_METRIC_WRITER", "enabled: true")
				libDir := filepath.Join(buildDir, "BOOT-INF", "lib")
				Expect(os.MkdirAll(libDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(libDir, "micrometer-core-1.12.0.jar"), []byte("fake"), 0644)).To(Succeed())
			})

			It("returns 'Metric Writer'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Metric Writer"))
			})
		})

		Context("with JBP_CONFIG_METRIC_WRITER enabled: true and micrometer in WEB-INF/lib", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_METRIC_WRITER", "enabled: true")
				libDir := filepath.Join(buildDir, "WEB-INF", "lib")
				Expect(os.MkdirAll(libDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(libDir, "micrometer-core-1.11.5.jar"), []byte("fake"), 0644)).To(Succeed())
			})

			It("returns 'Metric Writer'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Metric Writer"))
			})
		})

		Context("with JBP_CONFIG_METRIC_WRITER enabled: true and micrometer in lib/", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_METRIC_WRITER", "enabled: true")
				libDir := filepath.Join(buildDir, "lib")
				Expect(os.MkdirAll(libDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(libDir, "micrometer-core-1.10.0.jar"), []byte("fake"), 0644)).To(Succeed())
			})

			It("returns 'Metric Writer'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Metric Writer"))
			})
		})

		Context("with JBP_CONFIG_METRIC_WRITER enabled: true but no micrometer JAR present", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_METRIC_WRITER", "enabled: true")
			})

			It("returns empty string (no Micrometer found)", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with enabled: true but only unrelated JARs in lib dirs", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_METRIC_WRITER", "enabled: true")
				libDir := filepath.Join(buildDir, "BOOT-INF", "lib")
				Expect(os.MkdirAll(libDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(libDir, "spring-boot-3.2.0.jar"), []byte("fake"), 0644)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(libDir, "logback-classic-1.4.0.jar"), []byte("fake"), 0644)).To(Succeed())
			})

			It("returns empty string (no Micrometer found)", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with inline YAML {enabled: true} and micrometer present", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_METRIC_WRITER", "{enabled: true}")
				libDir := filepath.Join(buildDir, "BOOT-INF", "lib")
				Expect(os.MkdirAll(libDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(libDir, "micrometer-core-1.12.0.jar"), []byte("fake"), 0644)).To(Succeed())
			})

			It("returns 'Metric Writer'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Metric Writer"))
			})
		})
	})

	Describe("Finalize", func() {
		Context("when the JAR is present", func() {
			BeforeEach(func() {
				writerDir := filepath.Join(depsDir, "0", "metric_writer")
				Expect(os.MkdirAll(writerDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(writerDir, "metric-writer-4.35.0.jar"), []byte("fake jar"), 0644)).To(Succeed())
			})

			It("writes a profile.d script", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "profile.d", "metric_writer.sh")).To(BeAnExistingFile())
			})

			It("profile.d script exports CLASSPATH containing the JAR path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "metric_writer.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("export CLASSPATH="))
				Expect(string(content)).To(ContainSubstring("metric-writer-4.35.0.jar"))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR"))
			})

			It("runtime path includes the deps index", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "metric_writer.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/metric_writer/metric-writer-4.35.0.jar"))
			})

			It("profile.d script does not embed the staging-time absolute path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "metric_writer.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(depsDir))
			})

			It("profile.d script sets CF_APP_ACCOUNT from VCAP_APPLICATION", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "metric_writer.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("CF_APP_ACCOUNT"))
			})

			It("profile.d script sets CF_APP_APPLICATION from VCAP_APPLICATION", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "metric_writer.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("CF_APP_APPLICATION"))
			})

			It("profile.d script sets CF_APP_ORGANIZATION from VCAP_APPLICATION", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "metric_writer.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("CF_APP_ORGANIZATION"))
			})

			It("profile.d script sets CF_APP_SPACE from VCAP_APPLICATION", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "metric_writer.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("CF_APP_SPACE"))
			})

			It("profile.d script sets CF_APP_INSTANCE_INDEX from CF_INSTANCE_INDEX", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "metric_writer.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("CF_APP_INSTANCE_INDEX"))
				Expect(string(content)).To(ContainSubstring("CF_INSTANCE_INDEX"))
			})

			It("profile.d script sets CF_APP_VERSION from VCAP_APPLICATION", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "metric_writer.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("CF_APP_VERSION"))
			})

			It("profile.d script sets CF_APP_CLUSTER from VCAP_APPLICATION", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "metric_writer.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("CF_APP_CLUSTER"))
			})
		})

		Context("when no JAR is present", func() {
			It("succeeds without writing a profile.d script", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "profile.d", "metric_writer.sh")).NotTo(BeAnExistingFile())
			})
		})

		Context("with a different JAR version", func() {
			BeforeEach(func() {
				writerDir := filepath.Join(depsDir, "0", "metric_writer")
				Expect(os.MkdirAll(writerDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(writerDir, "metric-writer-4.30.0.jar"), []byte("fake jar"), 0644)).To(Succeed())
			})

			It("references the correct JAR filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "metric_writer.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("metric-writer-4.30.0.jar"))
			})
		})
	})
})
