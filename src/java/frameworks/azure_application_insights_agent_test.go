package frameworks_test

import (
	"fmt"
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/frameworks"
	"github.com/cloudfoundry/java-buildpack/src/java/resources"
	"github.com/cloudfoundry/libbuildpack"
)

func newAzureContext(buildDir, cacheDir, depsDir string) *common.Context {
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

// azureVCAPServices builds a VCAP_SERVICES JSON for an Azure Application Insights service.
// extraCreds is an optional comma-separated list of additional JSON key:value pairs.
func azureVCAPServices(label, name string, tags []string, extraCreds string) string {
	tagJSON := "[]"
	if len(tags) > 0 {
		parts := make([]string, len(tags))
		for i, t := range tags {
			parts[i] = fmt.Sprintf("%q", t)
		}
		tagJSON = "[" + joinAzureStrings(parts) + "]"
	}
	creds := `"placeholder":"true"`
	if extraCreds != "" {
		creds += "," + extraCreds
	}
	return fmt.Sprintf(`{%q:[{"name":%q,"label":%q,"tags":%s,"credentials":{%s}}]}`,
		label, name, label, tagJSON, creds)
}

func joinAzureStrings(ss []string) string {
	result := ""
	for i, s := range ss {
		if i > 0 {
			result += ","
		}
		result += s
	}
	return result
}

// installAzureAgent creates a versioned applicationinsights-agent JAR under depsDir.
func installAzureAgent(depsDir, version string) {
	agentDir := filepath.Join(depsDir, "0", "azure_application_insights_agent")
	Expect(os.MkdirAll(agentDir, 0755)).To(Succeed())
	Expect(os.WriteFile(
		filepath.Join(agentDir, "applicationinsights-agent-"+version+".jar"),
		[]byte("fake jar"), 0644,
	)).To(Succeed())
}

var _ = Describe("Azure Application Insights Agent", func() {
	var (
		fw       *frameworks.AzureApplicationInsightsAgentFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "azure-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "azure-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "azure-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewAzureApplicationInsightsAgentFramework(newAzureContext(buildDir, cacheDir, depsDir))
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(cacheDir)
		os.RemoveAll(depsDir)
		os.Unsetenv("APPLICATIONINSIGHTS_CONNECTION_STRING")
		os.Unsetenv("APPINSIGHTS_INSTRUMENTATIONKEY")
		os.Unsetenv("VCAP_SERVICES")
		os.Unsetenv("VCAP_APPLICATION")
	})

	Describe("Detect", func() {
		Context("with no environment set", func() {
			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with APPLICATIONINSIGHTS_CONNECTION_STRING set", func() {
			BeforeEach(func() {
				os.Setenv("APPLICATIONINSIGHTS_CONNECTION_STRING", "InstrumentationKey=abc;IngestionEndpoint=https://eastus.in.applicationinsights.azure.com/")
			})

			It("returns 'Azure Application Insights'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Azure Application Insights"))
			})
		})

		Context("with APPINSIGHTS_INSTRUMENTATIONKEY set", func() {
			BeforeEach(func() {
				os.Setenv("APPINSIGHTS_INSTRUMENTATIONKEY", "00000000-0000-0000-0000-000000000000")
			})

			It("returns 'Azure Application Insights'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Azure Application Insights"))
			})
		})

		Context("with service bound by label 'azure-application-insights'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", azureVCAPServices("azure-application-insights", "my-ai", nil, ""))
			})

			It("returns 'Azure Application Insights'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Azure Application Insights"))
			})
		})

		Context("with service bound by label 'application-insights'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", azureVCAPServices("application-insights", "my-ai", nil, ""))
			})

			It("returns 'Azure Application Insights'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Azure Application Insights"))
			})
		})

		Context("with service bound by label 'applicationinsights'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", azureVCAPServices("applicationinsights", "my-ai", nil, ""))
			})

			It("returns 'Azure Application Insights'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Azure Application Insights"))
			})
		})

		Context("with service tagged 'application-insights'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", azureVCAPServices("user-provided", "my-svc", []string{"application-insights"}, ""))
			})

			It("returns 'Azure Application Insights'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Azure Application Insights"))
			})
		})

		Context("with service tagged 'applicationinsights'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", azureVCAPServices("user-provided", "my-svc", []string{"applicationinsights"}, ""))
			})

			It("returns 'Azure Application Insights'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Azure Application Insights"))
			})
		})

		Context("with service tagged 'app-insights'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", azureVCAPServices("user-provided", "my-svc", []string{"app-insights"}, ""))
			})

			It("returns 'Azure Application Insights'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Azure Application Insights"))
			})
		})

		Context("with service name containing 'application-insights'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", azureVCAPServices("user-provided", "prod-application-insights-svc", nil, ""))
			})

			It("returns 'Azure Application Insights'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Azure Application Insights"))
			})
		})

		Context("with service name containing 'applicationinsights'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", azureVCAPServices("user-provided", "my-applicationinsights", nil, ""))
			})

			It("returns 'Azure Application Insights'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Azure Application Insights"))
			})
		})

		Context("with service name containing 'app-insights'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", azureVCAPServices("user-provided", "my-app-insights", nil, ""))
			})

			It("returns 'Azure Application Insights'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Azure Application Insights"))
			})
		})

		Context("with service name containing 'insights'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", azureVCAPServices("user-provided", "my-insights-svc", nil, ""))
			})

			It("returns 'Azure Application Insights'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Azure Application Insights"))
			})
		})

		Context("with an unrelated service bound", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", azureVCAPServices("newrelic", "my-newrelic", []string{"apm"}, ""))
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
		Context("with agent JAR present and no credentials", func() {
			BeforeEach(func() {
				installAzureAgent(depsDir, "3.4.0")
			})

			It("writes the opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "13_azure_application_insights_agent.opts")).To(BeAnExistingFile())
			})

			It("opts file contains -javaagent pointing to the runtime JAR path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "13_azure_application_insights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-javaagent:"))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/azure_application_insights_agent/applicationinsights-agent-3.4.0.jar"))
			})

			It("opts file does not embed the staging-time absolute path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "13_azure_application_insights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(depsDir))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR"))
			})

			It("uses priority prefix 13 in the filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				entries, err := os.ReadDir(filepath.Join(depsDir, "0", "java_opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(entries).To(HaveLen(1))
				Expect(entries[0].Name()).To(Equal("13_azure_application_insights_agent.opts"))
			})

			It("opts file contains no connection string or instrumentation key when absent", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "13_azure_application_insights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring("applicationinsights.connection.string"))
				Expect(string(content)).NotTo(ContainSubstring("applicationinsights.instrumentation-key"))
			})
		})

		Context("with connection string from APPLICATIONINSIGHTS_CONNECTION_STRING env var", func() {
			BeforeEach(func() {
				installAzureAgent(depsDir, "3.4.0")
				os.Setenv("APPLICATIONINSIGHTS_CONNECTION_STRING", "InstrumentationKey=abc123;IngestionEndpoint=https://eastus.in.applicationinsights.azure.com/")
			})

			It("opts file contains -Dapplicationinsights.connection.string", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "13_azure_application_insights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dapplicationinsights.connection.string=InstrumentationKey=abc123;IngestionEndpoint=https://eastus.in.applicationinsights.azure.com/"))
			})
		})

		Context("with instrumentation key from APPINSIGHTS_INSTRUMENTATIONKEY env var", func() {
			BeforeEach(func() {
				installAzureAgent(depsDir, "3.4.0")
				os.Setenv("APPINSIGHTS_INSTRUMENTATIONKEY", "00000000-1111-2222-3333-444444444444")
			})

			It("opts file contains -Dapplicationinsights.instrumentation-key", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "13_azure_application_insights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dapplicationinsights.instrumentation-key=00000000-1111-2222-3333-444444444444"))
			})
		})

		Context("with connection_string credential in service binding (snake_case)", func() {
			BeforeEach(func() {
				installAzureAgent(depsDir, "3.4.0")
				os.Setenv("VCAP_SERVICES", azureVCAPServices("azure-application-insights", "my-ai", nil,
					`"connection_string":"InstrumentationKey=binding-key"`))
			})

			It("opts file contains -Dapplicationinsights.connection.string from binding", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "13_azure_application_insights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dapplicationinsights.connection.string=InstrumentationKey=binding-key"))
			})
		})

		Context("with connectionString credential in service binding (camelCase)", func() {
			BeforeEach(func() {
				installAzureAgent(depsDir, "3.4.0")
				os.Setenv("VCAP_SERVICES", azureVCAPServices("azure-application-insights", "my-ai", nil,
					`"connectionString":"InstrumentationKey=camel-key"`))
			})

			It("opts file contains -Dapplicationinsights.connection.string from camelCase binding", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "13_azure_application_insights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dapplicationinsights.connection.string=InstrumentationKey=camel-key"))
			})
		})

		Context("with instrumentation_key credential in service binding (snake_case)", func() {
			BeforeEach(func() {
				installAzureAgent(depsDir, "3.4.0")
				os.Setenv("VCAP_SERVICES", azureVCAPServices("azure-application-insights", "my-ai", nil,
					`"instrumentation_key":"ikey-snake-abc"`))
			})

			It("opts file contains -Dapplicationinsights.instrumentation-key from binding", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "13_azure_application_insights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dapplicationinsights.instrumentation-key=ikey-snake-abc"))
			})
		})

		Context("with instrumentationKey credential in service binding (camelCase)", func() {
			BeforeEach(func() {
				installAzureAgent(depsDir, "3.4.0")
				os.Setenv("VCAP_SERVICES", azureVCAPServices("azure-application-insights", "my-ai", nil,
					`"instrumentationKey":"ikey-camel-xyz"`))
			})

			It("opts file contains -Dapplicationinsights.instrumentation-key from camelCase binding", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "13_azure_application_insights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dapplicationinsights.instrumentation-key=ikey-camel-xyz"))
			})
		})

		Context("with connection string taking precedence over instrumentation key when both present in env", func() {
			BeforeEach(func() {
				installAzureAgent(depsDir, "3.4.0")
				os.Setenv("APPLICATIONINSIGHTS_CONNECTION_STRING", "InstrumentationKey=conn-str-key")
				os.Setenv("APPINSIGHTS_INSTRUMENTATIONKEY", "plain-ikey")
			})

			It("opts file uses connection string and not instrumentation key", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "13_azure_application_insights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dapplicationinsights.connection.string=InstrumentationKey=conn-str-key"))
				Expect(string(content)).NotTo(ContainSubstring("applicationinsights.instrumentation-key"))
			})
		})

		Context("with application name from VCAP_APPLICATION", func() {
			BeforeEach(func() {
				installAzureAgent(depsDir, "3.4.0")
				os.Setenv("VCAP_APPLICATION", `{"application_name":"my-cf-app"}`)
			})

			It("opts file contains -Dapplicationinsights.role.name", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "13_azure_application_insights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dapplicationinsights.role.name=my-cf-app"))
			})
		})

		Context("with no application name available", func() {
			BeforeEach(func() {
				installAzureAgent(depsDir, "3.4.0")
			})

			It("opts file does not contain role.name flag", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "13_azure_application_insights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring("applicationinsights.role.name"))
			})
		})

		Context("when the agent JAR is not present", func() {
			It("returns an error", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("azure application insights agent not found during finalize"))
			})
		})
	})

	Describe("Embedded config", func() {
		const embeddedPath = "azure_application_insights_agent/AI-Agent.xml"

		It("exists in embedded resources", func() {
			Expect(resources.Exists(embeddedPath)).To(BeTrue())
		})

		It("has expected XML structure", func() {
			configData, err := resources.GetResource(embeddedPath)
			Expect(err).NotTo(HaveOccurred())
			configStr := string(configData)
			Expect(configStr).To(ContainSubstring("<?xml version=\"1.0\" encoding=\"utf-8\"?>"))
			Expect(configStr).To(ContainSubstring("<ApplicationInsightsAgent>"))
			Expect(configStr).To(ContainSubstring("<Instrumentation>"))
			Expect(configStr).To(ContainSubstring("<BuiltIn"))
			Expect(configStr).To(ContainSubstring("<Jedis"))
			Expect(configStr).To(ContainSubstring("<MaxStatementQueryLimitInMS>"))
		})

		It("can be written to disk", func() {
			tmpDir, err := os.MkdirTemp("", "azure-cfg")
			Expect(err).NotTo(HaveOccurred())
			defer os.RemoveAll(tmpDir)

			agentDir := filepath.Join(tmpDir, "azure_application_insights_agent")
			Expect(os.MkdirAll(agentDir, 0755)).To(Succeed())
			configData, err := resources.GetResource(embeddedPath)
			Expect(err).NotTo(HaveOccurred())
			configPath := filepath.Join(agentDir, "AI-Agent.xml")
			Expect(os.WriteFile(configPath, configData, 0644)).To(Succeed())
			written, err := os.ReadFile(configPath)
			Expect(err).NotTo(HaveOccurred())
			Expect(string(written)).To(ContainSubstring("<ApplicationInsightsAgent>"))
		})

		It("does not overwrite an existing user-provided config", func() {
			tmpDir, err := os.MkdirTemp("", "azure-cfg")
			Expect(err).NotTo(HaveOccurred())
			defer os.RemoveAll(tmpDir)

			agentDir := filepath.Join(tmpDir, "azure_application_insights_agent")
			Expect(os.MkdirAll(agentDir, 0755)).To(Succeed())
			configPath := filepath.Join(agentDir, "AI-Agent.xml")
			userConfig := "<!-- user config -->\n<ApplicationInsightsAgent><Instrumentation><BuiltIn enabled=\"false\"/></Instrumentation></ApplicationInsightsAgent>"
			Expect(os.WriteFile(configPath, []byte(userConfig), 0644)).To(Succeed())

			_, statErr := os.Stat(configPath)
			Expect(statErr).NotTo(HaveOccurred())
			existing, err := os.ReadFile(configPath)
			Expect(err).NotTo(HaveOccurred())
			Expect(string(existing)).To(ContainSubstring("<!-- user config -->"))
			Expect(string(existing)).To(ContainSubstring("enabled=\"false\""))
		})
	})
})
