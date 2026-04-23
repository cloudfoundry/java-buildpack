package frameworks_test

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/frameworks"
	"github.com/cloudfoundry/libbuildpack"
)

func newCheckmarxContext(buildDir, cacheDir, depsDir string) *common.Context {
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

// checkmarxVCAPServices builds a VCAP_SERVICES JSON for a Checkmarx service.
// agentURL is placed in the "url" credential; extraCreds is an optional
// comma-separated list of additional JSON key:value pairs.
func checkmarxVCAPServices(label, name string, tags []string, agentURL, extraCreds string) string {
	tagJSON := "[]"
	if len(tags) > 0 {
		parts := make([]string, len(tags))
		for i, t := range tags {
			parts[i] = fmt.Sprintf("%q", t)
		}
		tagJSON = "[" + joinCXStrings(parts) + "]"
	}
	creds := fmt.Sprintf(`"url":%q`, agentURL)
	if extraCreds != "" {
		creds += "," + extraCreds
	}
	return fmt.Sprintf(`{%q:[{"name":%q,"label":%q,"tags":%s,"credentials":{%s}}]}`,
		label, name, label, tagJSON, creds)
}

func joinCXStrings(ss []string) string {
	result := ""
	for i, s := range ss {
		if i > 0 {
			result += ","
		}
		result += s
	}
	return result
}

// installCXAgent creates cx-agent.jar at the expected path under depsDir.
func installCXAgent(depsDir string) {
	agentDir := filepath.Join(depsDir, "0", "checkmarx_iast_agent")
	Expect(os.MkdirAll(agentDir, 0755)).To(Succeed())
	Expect(os.WriteFile(filepath.Join(agentDir, "cx-agent.jar"), []byte("fake jar"), 0644)).To(Succeed())
}

var _ = Describe("Checkmarx IAST Agent", func() {
	var (
		fw       *frameworks.CheckmarxIASTAgentFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "cx-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "cx-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "cx-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewCheckmarxIASTAgentFramework(newCheckmarxContext(buildDir, cacheDir, depsDir))
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(cacheDir)
		os.RemoveAll(depsDir)
		os.Unsetenv("VCAP_SERVICES")
	})

	Describe("Detect", func() {
		Context("with no VCAP_SERVICES set", func() {
			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with service bound by label 'checkmarx-iast'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", checkmarxVCAPServices("checkmarx-iast", "my-cx", nil, "https://cx.example.com/agent.jar", ""))
			})

			It("returns 'checkmarx-iast-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("checkmarx-iast-agent"))
			})
		})

		Context("with service bound by label 'checkmarx'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", checkmarxVCAPServices("checkmarx", "my-cx", nil, "https://cx.example.com/agent.jar", ""))
			})

			It("returns 'checkmarx-iast-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("checkmarx-iast-agent"))
			})
		})

		Context("with service tagged 'checkmarx-iast'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", checkmarxVCAPServices("user-provided", "my-sec-svc", []string{"checkmarx-iast"}, "https://cx.example.com/agent.jar", ""))
			})

			It("returns 'checkmarx-iast-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("checkmarx-iast-agent"))
			})
		})

		Context("with service tagged 'checkmarx'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", checkmarxVCAPServices("user-provided", "my-sec-svc", []string{"checkmarx"}, "https://cx.example.com/agent.jar", ""))
			})

			It("returns 'checkmarx-iast-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("checkmarx-iast-agent"))
			})
		})

		Context("with service tagged 'iast'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", checkmarxVCAPServices("user-provided", "my-iast-svc", []string{"iast"}, "https://cx.example.com/agent.jar", ""))
			})

			It("returns 'checkmarx-iast-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("checkmarx-iast-agent"))
			})
		})

		Context("with service name containing 'checkmarx'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", checkmarxVCAPServices("user-provided", "prod-checkmarx-iast", nil, "https://cx.example.com/agent.jar", ""))
			})

			It("returns 'checkmarx-iast-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("checkmarx-iast-agent"))
			})
		})

		Context("with an unrelated service bound", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", checkmarxVCAPServices("newrelic", "my-newrelic", []string{"apm"}, "https://nr.example.com", ""))
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

	Describe("Supply", func() {
		var server *httptest.Server

		BeforeEach(func() {
			server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(http.StatusOK)
				w.Write([]byte("fake agent jar content"))
			}))
		})

		AfterEach(func() {
			server.Close()
		})

		Context("with a valid agent URL in service binding", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", checkmarxVCAPServices("checkmarx-iast", "my-cx", nil, server.URL+"/cx-agent.jar", ""))
			})

			It("downloads cx-agent.jar to the agent directory", func() {
				Expect(fw.Supply()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "checkmarx_iast_agent", "cx-agent.jar")).To(BeAnExistingFile())
			})

			It("writes the downloaded content to the JAR file", func() {
				Expect(fw.Supply()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "checkmarx_iast_agent", "cx-agent.jar"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(Equal("fake agent jar content"))
			})
		})

		Context("with agent_url key instead of url", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", fmt.Sprintf(
					`{"checkmarx-iast":[{"name":"my-cx","label":"checkmarx-iast","tags":[],"credentials":{"agent_url":%q}}]}`,
					server.URL+"/cx-agent.jar",
				))
			})

			It("downloads the agent using the agent_url key", func() {
				Expect(fw.Supply()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "checkmarx_iast_agent", "cx-agent.jar")).To(BeAnExistingFile())
			})
		})

		Context("when URL is missing from credentials", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", `{"checkmarx-iast":[{"name":"my-cx","label":"checkmarx-iast","tags":[],"credentials":{"other":"value"}}]}`)
			})

			It("returns an error", func() {
				err := fw.Supply()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("URL not found"))
			})
		})

		Context("when the download server returns a non-200 status", func() {
			BeforeEach(func() {
				errorServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					w.WriteHeader(http.StatusNotFound)
				}))
				DeferCleanup(errorServer.Close)
				os.Setenv("VCAP_SERVICES", checkmarxVCAPServices("checkmarx-iast", "my-cx", nil, errorServer.URL+"/cx-agent.jar", ""))
			})

			It("returns an error", func() {
				err := fw.Supply()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("HTTP 404"))
			})
		})

		Context("when no VCAP_SERVICES is set", func() {
			It("returns an error", func() {
				err := fw.Supply()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("URL not found"))
			})
		})
	})

	Describe("Finalize", func() {
		Context("with cx-agent.jar present and no optional credentials", func() {
			BeforeEach(func() {
				installCXAgent(depsDir)
			})

			It("writes the opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "14_checkmarx_iast_agent.opts")).To(BeAnExistingFile())
			})

			It("opts file contains -javaagent pointing to the runtime cx-agent.jar path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "14_checkmarx_iast_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-javaagent:"))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/checkmarx_iast_agent/cx-agent.jar"))
			})

			It("opts file does not embed the staging-time absolute path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "14_checkmarx_iast_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(depsDir))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR"))
			})

			It("uses priority prefix 14 in the filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				entries, err := os.ReadDir(filepath.Join(depsDir, "0", "java_opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(entries).To(HaveLen(1))
				Expect(entries[0].Name()).To(Equal("14_checkmarx_iast_agent.opts"))
			})

			It("opts file does not contain manager URL or API key flags when absent", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "14_checkmarx_iast_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring("checkmarx.manager.url"))
				Expect(string(content)).NotTo(ContainSubstring("checkmarx.api.key"))
			})
		})

		Context("with manager_url credential (snake_case)", func() {
			BeforeEach(func() {
				installCXAgent(depsDir)
				os.Setenv("VCAP_SERVICES", checkmarxVCAPServices("checkmarx-iast", "my-cx", nil, "https://cx.example.com/agent.jar",
					`"manager_url":"https://manager.example.com"`))
			})

			It("opts file contains -Dcheckmarx.manager.url", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "14_checkmarx_iast_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcheckmarx.manager.url=https://manager.example.com"))
			})
		})

		Context("with managerUrl credential (camelCase)", func() {
			BeforeEach(func() {
				installCXAgent(depsDir)
				os.Setenv("VCAP_SERVICES", checkmarxVCAPServices("checkmarx-iast", "my-cx", nil, "https://cx.example.com/agent.jar",
					`"managerUrl":"https://mgr-camel.example.com"`))
			})

			It("opts file contains -Dcheckmarx.manager.url from camelCase key", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "14_checkmarx_iast_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcheckmarx.manager.url=https://mgr-camel.example.com"))
			})
		})

		Context("with api_key credential (snake_case)", func() {
			BeforeEach(func() {
				installCXAgent(depsDir)
				os.Setenv("VCAP_SERVICES", checkmarxVCAPServices("checkmarx-iast", "my-cx", nil, "https://cx.example.com/agent.jar",
					`"api_key":"secret-key-abc"`))
			})

			It("opts file contains -Dcheckmarx.api.key", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "14_checkmarx_iast_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcheckmarx.api.key=secret-key-abc"))
			})
		})

		Context("with apiKey credential (camelCase)", func() {
			BeforeEach(func() {
				installCXAgent(depsDir)
				os.Setenv("VCAP_SERVICES", checkmarxVCAPServices("checkmarx-iast", "my-cx", nil, "https://cx.example.com/agent.jar",
					`"apiKey":"camel-key-xyz"`))
			})

			It("opts file contains -Dcheckmarx.api.key from camelCase key", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "14_checkmarx_iast_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcheckmarx.api.key=camel-key-xyz"))
			})
		})

		Context("with all optional credentials present", func() {
			BeforeEach(func() {
				installCXAgent(depsDir)
				os.Setenv("VCAP_SERVICES", checkmarxVCAPServices("checkmarx-iast", "my-cx", nil, "https://cx.example.com/agent.jar",
					`"manager_url":"https://manager.example.com","api_key":"full-key-123"`))
			})

			It("opts file contains both -Dcheckmarx.manager.url and -Dcheckmarx.api.key", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "14_checkmarx_iast_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcheckmarx.manager.url=https://manager.example.com"))
				Expect(string(content)).To(ContainSubstring("-Dcheckmarx.api.key=full-key-123"))
			})
		})

		Context("with service detected via name pattern", func() {
			BeforeEach(func() {
				installCXAgent(depsDir)
				os.Setenv("VCAP_SERVICES", checkmarxVCAPServices("user-provided", "prod-checkmarx-svc", nil, "https://cx.example.com/agent.jar",
					`"manager_url":"https://manager.example.com"`))
			})

			It("opts file contains the credential from the user-provided binding", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "14_checkmarx_iast_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcheckmarx.manager.url=https://manager.example.com"))
			})
		})
	})
})
