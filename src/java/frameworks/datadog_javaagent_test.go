package frameworks_test

import (
	"archive/zip"
	"fmt"
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/frameworks"
	"github.com/cloudfoundry/libbuildpack"
)

func newDatadogContext(buildDir, cacheDir, depsDir string) *common.Context {
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

// ddVCAPServices builds a VCAP_SERVICES JSON for a Datadog service.
func ddVCAPServices(label, name string, tags []string, extraCreds string) string {
	tagJSON := "[]"
	if len(tags) > 0 {
		parts := make([]string, len(tags))
		for i, t := range tags {
			parts[i] = fmt.Sprintf("%q", t)
		}
		tagJSON = "[" + joinDDStrings(parts) + "]"
	}
	creds := `"placeholder":"true"`
	if extraCreds != "" {
		creds += "," + extraCreds
	}
	return fmt.Sprintf(`{%q:[{"name":%q,"label":%q,"tags":%s,"credentials":{%s}}]}`,
		label, name, label, tagJSON, creds)
}

func joinDDStrings(ss []string) string {
	result := ""
	for i, s := range ss {
		if i > 0 {
			result += ","
		}
		result += s
	}
	return result
}

// installDatadogAgent creates a versioned dd-java-agent JAR under depsDir.
// If withClassdata is true the JAR contains a .classdata entry so fixClassCount runs.
func installDatadogAgent(depsDir, version string, withClassdata bool) {
	agentDir := filepath.Join(depsDir, "0", "datadog_javaagent")
	Expect(os.MkdirAll(agentDir, 0755)).To(Succeed())

	jarPath := filepath.Join(agentDir, "dd-java-agent-"+version+".jar")

	f, err := os.Create(jarPath)
	Expect(err).NotTo(HaveOccurred())
	defer f.Close()

	zw := zip.NewWriter(f)
	defer zw.Close()

	// Always add a placeholder entry so the zip is valid
	w, err := zw.Create("META-INF/MANIFEST.MF")
	Expect(err).NotTo(HaveOccurred())
	w.Write([]byte("Manifest-Version: 1.0\n"))

	if withClassdata {
		w2, err := zw.Create("some/file.classdata")
		Expect(err).NotTo(HaveOccurred())
		w2.Write([]byte("classdata"))
	}
}

var _ = Describe("Datadog JavaAgent", func() {
	var (
		fw       *frameworks.DatadogJavaagentFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "dd-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "dd-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "dd-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewDatadogJavaagentFramework(newDatadogContext(buildDir, cacheDir, depsDir))
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(cacheDir)
		os.RemoveAll(depsDir)
		os.Unsetenv("DD_API_KEY")
		os.Unsetenv("DD_APM_ENABLED")
		os.Unsetenv("DD_SERVICE")
		os.Unsetenv("DD_VERSION")
		os.Unsetenv("VCAP_SERVICES")
		os.Unsetenv("VCAP_APPLICATION")
	})

	Describe("Detect", func() {
		Context("with no DD_API_KEY and no service binding", func() {
			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with DD_API_KEY set", func() {
			BeforeEach(func() {
				os.Setenv("DD_API_KEY", "abc123")
			})

			It("returns 'datadog-javaagent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("datadog-javaagent"))
			})
		})

		Context("with service bound by label 'datadog'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", ddVCAPServices("datadog", "my-datadog", nil, ""))
			})

			It("returns 'datadog-javaagent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("datadog-javaagent"))
			})
		})

		Context("with service tagged 'datadog'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", ddVCAPServices("user-provided", "my-apm-svc", []string{"datadog", "apm"}, ""))
			})

			It("returns 'datadog-javaagent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("datadog-javaagent"))
			})
		})

		Context("with service name containing 'datadog'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", ddVCAPServices("user-provided", "prod-datadog-apm", nil, ""))
			})

			It("returns 'datadog-javaagent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("datadog-javaagent"))
			})
		})

		Context("with DD_APM_ENABLED=false and DD_API_KEY set", func() {
			BeforeEach(func() {
				os.Setenv("DD_API_KEY", "abc123")
				os.Setenv("DD_APM_ENABLED", "false")
			})

			It("returns empty string (APM explicitly disabled)", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with DD_APM_ENABLED=false and service binding", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", ddVCAPServices("datadog", "my-datadog", nil, ""))
				os.Setenv("DD_APM_ENABLED", "false")
			})

			It("returns empty string (APM explicitly disabled)", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with DD_APM_ENABLED set to a non-false value", func() {
			BeforeEach(func() {
				os.Setenv("DD_API_KEY", "abc123")
				os.Setenv("DD_APM_ENABLED", "true")
			})

			It("returns 'datadog-javaagent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("datadog-javaagent"))
			})
		})

		Context("with an unrelated service bound", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", ddVCAPServices("newrelic", "my-newrelic", []string{"apm"}, ""))
			})

			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with invalid VCAP_SERVICES JSON", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", "{invalid json")
			})

			It("returns empty string without error", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})
	})

	Describe("Finalize", func() {
		Context("with agent JAR present and no optional env vars", func() {
			BeforeEach(func() {
				installDatadogAgent(depsDir, "1.28.0", false)
			})

			It("writes the opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "19_datadog_javaagent.opts")).To(BeAnExistingFile())
			})

			It("opts file contains -javaagent pointing to the runtime JAR path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "19_datadog_javaagent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-javaagent:"))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/datadog_javaagent/dd-java-agent-1.28.0.jar"))
			})

			It("opts file does not embed the staging-time absolute path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "19_datadog_javaagent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(depsDir))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR"))
			})

			It("uses priority prefix 19 in the filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				entries, err := os.ReadDir(filepath.Join(depsDir, "0", "java_opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(entries).To(HaveLen(1))
				Expect(entries[0].Name()).To(Equal("19_datadog_javaagent.opts"))
			})
		})

		Context("with application name from VCAP_APPLICATION and DD_SERVICE not set", func() {
			BeforeEach(func() {
				installDatadogAgent(depsDir, "1.28.0", false)
				os.Setenv("VCAP_APPLICATION", `{"application_name":"my-cf-app"}`)
			})

			It("opts file contains -Ddd.service with the application name", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "19_datadog_javaagent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring(`-Ddd.service="my-cf-app"`))
			})
		})

		Context("with DD_SERVICE set (suppresses VCAP_APPLICATION service name)", func() {
			BeforeEach(func() {
				installDatadogAgent(depsDir, "1.28.0", false)
				os.Setenv("VCAP_APPLICATION", `{"application_name":"vcap-app"}`)
				os.Setenv("DD_SERVICE", "explicit-service")
			})

			It("opts file does not contain -Ddd.service", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "19_datadog_javaagent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring("-Ddd.service"))
			})
		})

		Context("with application version from VCAP_APPLICATION", func() {
			BeforeEach(func() {
				installDatadogAgent(depsDir, "1.28.0", false)
				os.Setenv("VCAP_APPLICATION", `{"application_name":"my-app","application_version":"v2.3.1"}`)
			})

			It("opts file contains -Ddd.version with the application version", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "19_datadog_javaagent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Ddd.version=v2.3.1"))
			})
		})

		Context("with DD_VERSION set (takes precedence over VCAP_APPLICATION)", func() {
			BeforeEach(func() {
				installDatadogAgent(depsDir, "1.28.0", false)
				os.Setenv("VCAP_APPLICATION", `{"application_name":"my-app","application_version":"vcap-ver"}`)
				os.Setenv("DD_VERSION", "explicit-ver")
			})

			It("opts file uses DD_VERSION value", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "19_datadog_javaagent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Ddd.version=explicit-ver"))
				Expect(string(content)).NotTo(ContainSubstring("vcap-ver"))
			})
		})

		Context("with no VCAP_APPLICATION and no DD_VERSION", func() {
			BeforeEach(func() {
				installDatadogAgent(depsDir, "1.28.0", false)
			})

			It("opts file does not contain -Ddd.version or -Ddd.service", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "19_datadog_javaagent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring("-Ddd.version"))
				Expect(string(content)).NotTo(ContainSubstring("-Ddd.service"))
			})
		})

		Context("with a JAR containing .classdata entries (shadow JAR creation)", func() {
			BeforeEach(func() {
				installDatadogAgent(depsDir, "1.28.0", true)
			})

			It("succeeds and writes the opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "19_datadog_javaagent.opts")).To(BeAnExistingFile())
			})

			It("creates the shadow datadog_fakeclasses.jar alongside the agent", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "datadog_fakeclasses.jar")).To(BeAnExistingFile())
			})
		})

		Context("when the agent JAR is not present", func() {
			It("returns an error", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("datadog Java agent JAR path not found during finalize"))
			})
		})
	})
})
