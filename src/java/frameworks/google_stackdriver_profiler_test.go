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

func newGSDContext(buildDir, cacheDir, depsDir string) *common.Context {
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

// gsdVCAPServices builds a VCAP_SERVICES JSON string for a Google Stackdriver service.
func gsdVCAPServices(label, name string, tags []string, extraCreds string) string {
	tagJSON := "[]"
	if len(tags) > 0 {
		parts := make([]string, len(tags))
		for i, t := range tags {
			parts[i] = fmt.Sprintf("%q", t)
		}
		tagJSON = "[" + joinGSDStrings(parts) + "]"
	}
	creds := `"placeholder":"true"`
	if extraCreds != "" {
		creds += "," + extraCreds
	}
	return fmt.Sprintf(`{%q:[{"name":%q,"label":%q,"tags":%s,"credentials":{%s}}]}`,
		label, name, label, tagJSON, creds)
}

func joinGSDStrings(ss []string) string {
	result := ""
	for i, s := range ss {
		if i > 0 {
			result += ","
		}
		result += s
	}
	return result
}

// installGSDAgent creates the expected profiler_java_agent.so under depsDir.
func installGSDAgent(depsDir string) {
	agentDir := filepath.Join(depsDir, "0", "google_stackdriver_profiler")
	Expect(os.MkdirAll(agentDir, 0755)).To(Succeed())
	Expect(os.WriteFile(filepath.Join(agentDir, "profiler_java_agent.so"), []byte("fake so"), 0644)).To(Succeed())
}

var _ = Describe("Google Stackdriver Profiler", func() {
	var (
		fw       *frameworks.GoogleStackdriverProfilerFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "gsd-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "gsd-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "gsd-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewGoogleStackdriverProfilerFramework(newGSDContext(buildDir, cacheDir, depsDir))
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(cacheDir)
		os.RemoveAll(depsDir)
		os.Unsetenv("GOOGLE_APPLICATION_CREDENTIALS")
		os.Unsetenv("VCAP_SERVICES")
		os.Unsetenv("VCAP_APPLICATION")
		os.Unsetenv("JBP_CONFIG_GOOGLE_STACKDRIVER_PROFILER")
	})

	Describe("Detect", func() {
		Context("with no environment set", func() {
			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with GOOGLE_APPLICATION_CREDENTIALS set", func() {
			BeforeEach(func() {
				os.Setenv("GOOGLE_APPLICATION_CREDENTIALS", "/var/vcap/data/key.json")
			})

			It("returns 'google-stackdriver-profiler'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("google-stackdriver-profiler"))
			})
		})

		Context("with service bound by label 'google-stackdriver-profiler'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", gsdVCAPServices("google-stackdriver-profiler", "my-profiler", nil, ""))
			})

			It("returns 'google-stackdriver-profiler'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("google-stackdriver-profiler"))
			})
		})

		Context("with service bound by label 'stackdriver-profiler'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", gsdVCAPServices("stackdriver-profiler", "my-profiler", nil, ""))
			})

			It("returns 'google-stackdriver-profiler'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("google-stackdriver-profiler"))
			})
		})

		Context("with service tagged 'stackdriver-profiler'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", gsdVCAPServices("user-provided", "my-gcp-svc", []string{"stackdriver-profiler", "gcp"}, ""))
			})

			It("returns 'google-stackdriver-profiler'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("google-stackdriver-profiler"))
			})
		})

		Context("with service name containing 'stackdriver-profiler'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", gsdVCAPServices("user-provided", "prod-stackdriver-profiler-svc", nil, ""))
			})

			It("returns 'google-stackdriver-profiler'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("google-stackdriver-profiler"))
			})
		})

		Context("with service name containing 'stackdriver'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", gsdVCAPServices("user-provided", "my-stackdriver", nil, ""))
			})

			It("returns 'google-stackdriver-profiler'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("google-stackdriver-profiler"))
			})
		})

		Context("with an unrelated service bound", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", gsdVCAPServices("newrelic", "my-newrelic", []string{"apm"}, ""))
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
		Context("with agent present and no credentials or app metadata", func() {
			BeforeEach(func() {
				installGSDAgent(depsDir)
			})

			It("writes the opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "22_google_stackdriver_profiler.opts")).To(BeAnExistingFile())
			})

			It("opts file contains -agentpath pointing to the runtime .so path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "22_google_stackdriver_profiler.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-agentpath:"))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/google_stackdriver_profiler/profiler_java_agent.so"))
			})

			It("opts file does not embed the staging-time absolute path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "22_google_stackdriver_profiler.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(depsDir))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR"))
			})

			It("uses priority prefix 22 in the filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				entries, err := os.ReadDir(filepath.Join(depsDir, "0", "java_opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(entries).To(HaveLen(1))
				Expect(entries[0].Name()).To(Equal("22_google_stackdriver_profiler.opts"))
			})
		})

		Context("with application name from VCAP_APPLICATION", func() {
			BeforeEach(func() {
				installGSDAgent(depsDir)
				os.Setenv("VCAP_APPLICATION", `{"application_name":"my-app"}`)
			})

			It("opts file contains -cprof_service with the application name", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "22_google_stackdriver_profiler.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-cprof_service=my-app"))
			})
		})

		Context("with application version from VCAP_APPLICATION", func() {
			BeforeEach(func() {
				installGSDAgent(depsDir)
				os.Setenv("VCAP_APPLICATION", `{"application_name":"my-app","application_version":"abc-123"}`)
			})

			It("opts file contains -cprof_service_version with the application version", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "22_google_stackdriver_profiler.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-cprof_service_version=abc-123"))
			})
		})

		Context("with application_name overridden via JBP_CONFIG_GOOGLE_STACKDRIVER_PROFILER", func() {
			BeforeEach(func() {
				installGSDAgent(depsDir)
				os.Setenv("VCAP_APPLICATION", `{"application_name":"vcap-app"}`)
				os.Setenv("JBP_CONFIG_GOOGLE_STACKDRIVER_PROFILER", "application_name: config-app")
			})

			It("opts file uses the configured application name", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "22_google_stackdriver_profiler.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-cprof_service=config-app"))
				Expect(string(content)).NotTo(ContainSubstring("vcap-app"))
			})
		})

		Context("with application_version overridden via JBP_CONFIG_GOOGLE_STACKDRIVER_PROFILER", func() {
			BeforeEach(func() {
				installGSDAgent(depsDir)
				os.Setenv("VCAP_APPLICATION", `{"application_name":"my-app","application_version":"vcap-ver"}`)
				os.Setenv("JBP_CONFIG_GOOGLE_STACKDRIVER_PROFILER", "application_version: config-ver")
			})

			It("opts file uses the configured application version", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "22_google_stackdriver_profiler.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-cprof_service_version=config-ver"))
				Expect(string(content)).NotTo(ContainSubstring("vcap-ver"))
			})
		})

		Context("with ProjectId credential in service binding (PascalCase key)", func() {
			BeforeEach(func() {
				installGSDAgent(depsDir)
				os.Setenv("VCAP_SERVICES", gsdVCAPServices(
					"google-stackdriver-profiler", "my-profiler", nil,
					`"ProjectId":"my-gcp-project"`,
				))
			})

			It("opts file contains -cprof_project_id from the binding", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "22_google_stackdriver_profiler.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-cprof_project_id=my-gcp-project"))
			})
		})

		Context("with project_id credential in service binding (snake_case key)", func() {
			BeforeEach(func() {
				installGSDAgent(depsDir)
				os.Setenv("VCAP_SERVICES", gsdVCAPServices(
					"google-stackdriver-profiler", "my-profiler", nil,
					`"project_id":"my-snake-project"`,
				))
			})

			It("opts file contains -cprof_project_id from the binding", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "22_google_stackdriver_profiler.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-cprof_project_id=my-snake-project"))
			})
		})

		Context("with all agent args present (service, version, project_id)", func() {
			BeforeEach(func() {
				installGSDAgent(depsDir)
				os.Setenv("VCAP_APPLICATION", `{"application_name":"full-app","application_version":"v2"}`)
				os.Setenv("VCAP_SERVICES", gsdVCAPServices(
					"google-stackdriver-profiler", "my-profiler", nil,
					`"project_id":"full-project"`,
				))
			})

			It("opts file contains all three agent args joined with commas", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "22_google_stackdriver_profiler.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-cprof_service=full-app"))
				Expect(string(content)).To(ContainSubstring("-cprof_service_version=v2"))
				Expect(string(content)).To(ContainSubstring("-cprof_project_id=full-project"))
			})
		})

		Context("when the agent .so file is not present", func() {
			It("returns an error", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("google stackdriver profiler agent not found during finalize"))
			})
		})
	})
})
