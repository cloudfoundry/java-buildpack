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

func newElasticContext(buildDir, cacheDir, depsDir string) *common.Context {
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

// elasticVCAPServices builds a VCAP_SERVICES JSON for an Elastic APM service.
// serverURL and secretToken are the required credentials; extraCreds is an optional
// comma-separated list of additional JSON key:value pairs.
func elasticVCAPServices(label, name string, tags []string, serverURL, secretToken, extraCreds string) string {
	tagJSON := "[]"
	if len(tags) > 0 {
		parts := make([]string, len(tags))
		for i, t := range tags {
			parts[i] = fmt.Sprintf("%q", t)
		}
		tagJSON = "[" + joinElasticStrings(parts) + "]"
	}
	creds := fmt.Sprintf(`"server_urls":%q,"secret_token":%q`, serverURL, secretToken)
	if extraCreds != "" {
		creds += "," + extraCreds
	}
	return fmt.Sprintf(`{%q:[{"name":%q,"label":%q,"tags":%s,"credentials":{%s}}]}`,
		label, name, label, tagJSON, creds)
}

func joinElasticStrings(ss []string) string {
	result := ""
	for i, s := range ss {
		if i > 0 {
			result += ","
		}
		result += s
	}
	return result
}

// installElasticAgent creates a versioned elastic-apm-agent JAR under depsDir.
func installElasticAgent(depsDir, version string) {
	agentDir := filepath.Join(depsDir, "0", "elastic_apm_agent")
	Expect(os.MkdirAll(agentDir, 0755)).To(Succeed())
	Expect(os.WriteFile(
		filepath.Join(agentDir, "elastic-apm-agent-"+version+".jar"),
		[]byte("fake jar"), 0644,
	)).To(Succeed())
}

var _ = Describe("Elastic APM Agent", func() {
	var (
		fw       *frameworks.ElasticApmAgentFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "elastic-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "elastic-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "elastic-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewElasticApmAgentFramework(newElasticContext(buildDir, cacheDir, depsDir))
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(cacheDir)
		os.RemoveAll(depsDir)
		os.Unsetenv("VCAP_SERVICES")
		os.Unsetenv("VCAP_APPLICATION")
	})

	Describe("Detect", func() {
		Context("with no VCAP_SERVICES set", func() {
			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with service bound by label 'elastic-apm' with required credentials", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", elasticVCAPServices("elastic-apm", "my-elastic", nil, "https://apm.example.com", "my-secret", ""))
			})

			It("returns 'elastic-apm-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("elastic-apm-agent"))
			})
		})

		Context("with service bound by label 'elastic' with required credentials", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", elasticVCAPServices("elastic", "my-elastic", nil, "https://apm.example.com", "my-secret", ""))
			})

			It("returns 'elastic-apm-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("elastic-apm-agent"))
			})
		})

		Context("with service tagged 'elastic-apm' with required credentials", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", elasticVCAPServices("user-provided", "my-apm-svc", []string{"elastic-apm"}, "https://apm.example.com", "my-secret", ""))
			})

			It("returns 'elastic-apm-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("elastic-apm-agent"))
			})
		})

		Context("with service tagged 'elastic' with required credentials", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", elasticVCAPServices("user-provided", "my-apm-svc", []string{"elastic"}, "https://apm.example.com", "my-secret", ""))
			})

			It("returns 'elastic-apm-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("elastic-apm-agent"))
			})
		})

		Context("with service name containing 'elastic-apm' with required credentials", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", elasticVCAPServices("user-provided", "prod-elastic-apm-svc", nil, "https://apm.example.com", "my-secret", ""))
			})

			It("returns 'elastic-apm-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("elastic-apm-agent"))
			})
		})

		Context("with service name containing 'elastic' with required credentials", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", elasticVCAPServices("user-provided", "my-elastic-svc", nil, "https://apm.example.com", "my-secret", ""))
			})

			It("returns 'elastic-apm-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("elastic-apm-agent"))
			})
		})

		Context("with singular server_url key instead of server_urls", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", fmt.Sprintf(
					`{"elastic-apm":[{"name":"my-elastic","label":"elastic-apm","tags":[],"credentials":{"server_url":"https://apm.example.com","secret_token":"tok"}}]}`,
				))
			})

			It("returns 'elastic-apm-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("elastic-apm-agent"))
			})
		})

		Context("with service present but secret_token missing", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", `{"elastic-apm":[{"name":"my-elastic","label":"elastic-apm","tags":[],"credentials":{"server_urls":"https://apm.example.com"}}]}`)
			})

			It("returns empty string (required credential missing)", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with service present but server_urls missing", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", `{"elastic-apm":[{"name":"my-elastic","label":"elastic-apm","tags":[],"credentials":{"secret_token":"tok"}}]}`)
			})

			It("returns empty string (required credential missing)", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with service present but credentials empty", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", `{"elastic-apm":[{"name":"my-elastic","label":"elastic-apm","tags":[],"credentials":{}}]}`)
			})

			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with an unrelated service bound", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", elasticVCAPServices("newrelic", "my-newrelic", []string{"apm"}, "https://nr.example.com", "tok", ""))
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
		Context("with agent JAR present and required credentials", func() {
			BeforeEach(func() {
				installElasticAgent(depsDir, "1.38.0")
				os.Setenv("VCAP_SERVICES", elasticVCAPServices("elastic-apm", "my-elastic", nil, "https://apm.example.com:8200", "tok123", ""))
			})

			It("writes the opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "19_elastic_apm_agent.opts")).To(BeAnExistingFile())
			})

			It("opts file contains -javaagent pointing to the runtime JAR path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "19_elastic_apm_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-javaagent:"))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/elastic_apm_agent/elastic-apm-agent-1.38.0.jar"))
			})

			It("opts file does not embed the staging-time absolute path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "19_elastic_apm_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(depsDir))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR"))
			})

			It("uses priority prefix 19 in the filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				entries, err := os.ReadDir(filepath.Join(depsDir, "0", "java_opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(entries).To(HaveLen(1))
				Expect(entries[0].Name()).To(Equal("19_elastic_apm_agent.opts"))
			})

			It("opts file contains -Delastic.apm.home pointing to the runtime agent dir", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "19_elastic_apm_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Delastic.apm.home=$DEPS_DIR/0/elastic_apm_agent"))
			})

			It("opts file contains server_urls system property", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "19_elastic_apm_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Delastic.apm.server_urls=https://apm.example.com:8200"))
			})

			It("opts file contains secret_token system property", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "19_elastic_apm_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Delastic.apm.secret_token=tok123"))
			})

			It("opts file contains default log_file_name=STDOUT", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "19_elastic_apm_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Delastic.apm.log_file_name=STDOUT"))
			})
		})

		Context("with singular server_url credential key", func() {
			BeforeEach(func() {
				installElasticAgent(depsDir, "1.38.0")
				os.Setenv("VCAP_SERVICES", fmt.Sprintf(
					`{"elastic-apm":[{"name":"my-elastic","label":"elastic-apm","tags":[],"credentials":{"server_url":"https://singular.example.com:8200","secret_token":"tok"}}]}`,
				))
			})

			It("opts file contains server_urls system property from singular key", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "19_elastic_apm_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Delastic.apm.server_urls=https://singular.example.com:8200"))
			})
		})

		Context("with service_name from VCAP_APPLICATION", func() {
			BeforeEach(func() {
				installElasticAgent(depsDir, "1.38.0")
				os.Setenv("VCAP_SERVICES", elasticVCAPServices("elastic-apm", "my-elastic", nil, "https://apm.example.com:8200", "tok", ""))
				os.Setenv("VCAP_APPLICATION", `{"application_name":"my-cf-app"}`)
			})

			It("opts file contains service_name system property", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "19_elastic_apm_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Delastic.apm.service_name=my-cf-app"))
			})
		})

		Context("with no VCAP_APPLICATION set", func() {
			BeforeEach(func() {
				installElasticAgent(depsDir, "1.38.0")
				os.Setenv("VCAP_SERVICES", elasticVCAPServices("elastic-apm", "my-elastic", nil, "https://apm.example.com:8200", "tok", ""))
			})

			It("opts file does not contain service_name system property", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "19_elastic_apm_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring("elastic.apm.service_name"))
			})
		})

		Context("with an extra credential overriding a default (e.g. log_file_name)", func() {
			BeforeEach(func() {
				installElasticAgent(depsDir, "1.38.0")
				os.Setenv("VCAP_SERVICES", elasticVCAPServices("elastic-apm", "my-elastic", nil, "https://apm.example.com:8200", "tok",
					`"log_file_name":"/var/log/elastic-apm.log"`))
			})

			It("opts file uses the credential value over the default", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "19_elastic_apm_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Delastic.apm.log_file_name="))
				Expect(string(content)).NotTo(ContainSubstring("-Delastic.apm.log_file_name=STDOUT"))
			})
		})

		Context("with an additional arbitrary credential passed through", func() {
			BeforeEach(func() {
				installElasticAgent(depsDir, "1.38.0")
				os.Setenv("VCAP_SERVICES", elasticVCAPServices("elastic-apm", "my-elastic", nil, "https://apm.example.com:8200", "tok",
					`"environment":"production"`))
			})

			It("opts file contains the arbitrary credential as a system property", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "19_elastic_apm_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Delastic.apm.environment=production"))
			})
		})

		Context("when the agent JAR is not present", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", elasticVCAPServices("elastic-apm", "my-elastic", nil, "https://apm.example.com:8200", "tok", ""))
			})

			It("returns an error", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("elastic apm agent jar not found during finalize"))
			})
		})
	})
})
