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

func newIntroscopeContext(buildDir, cacheDir, depsDir string) *common.Context {
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

// introscopeVCAPServices builds a VCAP_SERVICES JSON for an Introscope service.
// extraCreds is an optional comma-separated list of additional JSON key:value pairs.
func introscopeVCAPServices(label, name string, tags []string, extraCreds string) string {
	tagJSON := "[]"
	if len(tags) > 0 {
		parts := make([]string, len(tags))
		for i, t := range tags {
			parts[i] = fmt.Sprintf("%q", t)
		}
		tagJSON = "[" + joinIntroscopeStrings(parts) + "]"
	}
	creds := `"placeholder":"true"`
	if extraCreds != "" {
		creds += "," + extraCreds
	}
	return fmt.Sprintf(`{%q:[{"name":%q,"label":%q,"tags":%s,"credentials":{%s}}]}`,
		label, name, label, tagJSON, creds)
}

func joinIntroscopeStrings(ss []string) string {
	result := ""
	for i, s := range ss {
		if i > 0 {
			result += ","
		}
		result += s
	}
	return result
}

// installIntroscopeAgent creates Agent.jar at the expected path under depsDir.
func installIntroscopeAgent(depsDir string) {
	agentDir := filepath.Join(depsDir, "0", "introscope_agent")
	Expect(os.MkdirAll(agentDir, 0755)).To(Succeed())
	Expect(os.WriteFile(filepath.Join(agentDir, "Agent.jar"), []byte("fake jar"), 0644)).To(Succeed())
}

var _ = Describe("Introscope Agent", func() {
	var (
		fw       *frameworks.IntroscopeAgentFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "introscope-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "introscope-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "introscope-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewIntroscopeAgentFramework(newIntroscopeContext(buildDir, cacheDir, depsDir))
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

		Context("with service bound by label 'introscope'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("introscope", "my-introscope", nil, ""))
			})

			It("returns 'introscope-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("introscope-agent"))
			})
		})

		Context("with service bound by label 'ca-apm'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("ca-apm", "my-ca-apm", nil, ""))
			})

			It("returns 'introscope-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("introscope-agent"))
			})
		})

		Context("with service bound by label 'ca-wily'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("ca-wily", "my-ca-wily", nil, ""))
			})

			It("returns 'introscope-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("introscope-agent"))
			})
		})

		Context("with service bound by label 'wily-introscope'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("wily-introscope", "my-wily", nil, ""))
			})

			It("returns 'introscope-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("introscope-agent"))
			})
		})

		Context("with service tagged 'introscope'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("user-provided", "my-apm-svc", []string{"introscope", "apm"}, ""))
			})

			It("returns 'introscope-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("introscope-agent"))
			})
		})

		Context("with service tagged 'ca-apm'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("user-provided", "my-apm-svc", []string{"ca-apm"}, ""))
			})

			It("returns 'introscope-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("introscope-agent"))
			})
		})

		Context("with service tagged 'wily'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("user-provided", "my-apm-svc", []string{"wily"}, ""))
			})

			It("returns 'introscope-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("introscope-agent"))
			})
		})

		Context("with service name containing 'introscope'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("user-provided", "prod-introscope-svc", nil, ""))
			})

			It("returns 'introscope-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("introscope-agent"))
			})
		})

		Context("with service name containing 'ca-apm'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("user-provided", "prod-ca-apm-monitor", nil, ""))
			})

			It("returns 'introscope-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("introscope-agent"))
			})
		})

		Context("with service name containing 'wily'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("user-provided", "my-wily-monitor", nil, ""))
			})

			It("returns 'introscope-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("introscope-agent"))
			})
		})

		Context("with an unrelated service bound", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("newrelic", "my-newrelic", []string{"apm"}, ""))
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
		Context("with Agent.jar present and no credentials", func() {
			BeforeEach(func() {
				installIntroscopeAgent(depsDir)
			})

			It("writes the opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "27_introscope_agent.opts")).To(BeAnExistingFile())
			})

			It("opts file contains -javaagent pointing to the runtime Agent.jar path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "27_introscope_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-javaagent:"))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/introscope_agent/Agent.jar"))
			})

			It("opts file does not embed the staging-time absolute path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "27_introscope_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(depsDir))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR"))
			})

			It("uses priority prefix 27 in the filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				entries, err := os.ReadDir(filepath.Join(depsDir, "0", "java_opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(entries).To(HaveLen(1))
				Expect(entries[0].Name()).To(Equal("27_introscope_agent.opts"))
			})

			It("opts file contains no agent name, EM host, or EM port flags when absent", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "27_introscope_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring("agent.name"))
				Expect(string(content)).NotTo(ContainSubstring("enterpriseManager.host"))
				Expect(string(content)).NotTo(ContainSubstring("enterpriseManager.port"))
			})
		})

		Context("with agent_name credential (snake_case)", func() {
			BeforeEach(func() {
				installIntroscopeAgent(depsDir)
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("introscope", "my-introscope", nil,
					`"agent_name":"MyApp"`))
			})

			It("opts file contains the agent name property", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "27_introscope_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcom.wily.introscope.agentProfile.agent.name=MyApp"))
			})
		})

		Context("with agentName credential (camelCase)", func() {
			BeforeEach(func() {
				installIntroscopeAgent(depsDir)
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("introscope", "my-introscope", nil,
					`"agentName":"CamelApp"`))
			})

			It("opts file contains the agent name property from camelCase key", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "27_introscope_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcom.wily.introscope.agentProfile.agent.name=CamelApp"))
			})
		})

		Context("with no agent_name credential but VCAP_APPLICATION present", func() {
			BeforeEach(func() {
				installIntroscopeAgent(depsDir)
				os.Setenv("VCAP_APPLICATION", `{"application_name":"vcap-app"}`)
			})

			It("opts file contains the agent name from VCAP_APPLICATION", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "27_introscope_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcom.wily.introscope.agentProfile.agent.name=vcap-app"))
			})
		})

		Context("with agent_name credential taking precedence over VCAP_APPLICATION", func() {
			BeforeEach(func() {
				installIntroscopeAgent(depsDir)
				os.Setenv("VCAP_APPLICATION", `{"application_name":"vcap-app"}`)
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("introscope", "my-introscope", nil,
					`"agent_name":"binding-name"`))
			})

			It("opts file uses the binding agent name", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "27_introscope_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcom.wily.introscope.agentProfile.agent.name=binding-name"))
				Expect(string(content)).NotTo(ContainSubstring("vcap-app"))
			})
		})

		Context("with em_host credential (snake_case)", func() {
			BeforeEach(func() {
				installIntroscopeAgent(depsDir)
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("introscope", "my-introscope", nil,
					`"em_host":"em.example.com"`))
			})

			It("opts file contains the EM host property", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "27_introscope_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcom.wily.introscope.agentProfile.agent.enterpriseManager.host=em.example.com"))
			})
		})

		Context("with emHost credential (camelCase)", func() {
			BeforeEach(func() {
				installIntroscopeAgent(depsDir)
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("introscope", "my-introscope", nil,
					`"emHost":"em-camel.example.com"`))
			})

			It("opts file contains the EM host property from camelCase key", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "27_introscope_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcom.wily.introscope.agentProfile.agent.enterpriseManager.host=em-camel.example.com"))
			})
		})

		Context("with em_port credential as string (snake_case)", func() {
			BeforeEach(func() {
				installIntroscopeAgent(depsDir)
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("introscope", "my-introscope", nil,
					`"em_port":"5001"`))
			})

			It("opts file contains the EM port property", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "27_introscope_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcom.wily.introscope.agentProfile.agent.enterpriseManager.port=5001"))
			})
		})

		Context("with emPort credential as number (camelCase)", func() {
			BeforeEach(func() {
				installIntroscopeAgent(depsDir)
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("introscope", "my-introscope", nil,
					`"emPort":5002`))
			})

			It("opts file contains the EM port property from numeric camelCase key", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "27_introscope_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcom.wily.introscope.agentProfile.agent.enterpriseManager.port=5002"))
			})
		})

		Context("with all credentials present", func() {
			BeforeEach(func() {
				installIntroscopeAgent(depsDir)
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("introscope", "my-introscope", nil,
					`"agent_name":"FullApp","em_host":"em.example.com","em_port":"5001"`))
			})

			It("opts file contains all three agent properties", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "27_introscope_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcom.wily.introscope.agentProfile.agent.name=FullApp"))
				Expect(string(content)).To(ContainSubstring("-Dcom.wily.introscope.agentProfile.agent.enterpriseManager.host=em.example.com"))
				Expect(string(content)).To(ContainSubstring("-Dcom.wily.introscope.agentProfile.agent.enterpriseManager.port=5001"))
			})
		})

		Context("with service detected via ca-apm label", func() {
			BeforeEach(func() {
				installIntroscopeAgent(depsDir)
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("ca-apm", "my-ca-apm", nil,
					`"em_host":"em.example.com"`))
			})

			It("opts file contains the credential from the ca-apm binding", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "27_introscope_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcom.wily.introscope.agentProfile.agent.enterpriseManager.host=em.example.com"))
			})
		})

		Context("with service detected via name pattern 'wily'", func() {
			BeforeEach(func() {
				installIntroscopeAgent(depsDir)
				os.Setenv("VCAP_SERVICES", introscopeVCAPServices("user-provided", "prod-wily-monitor", nil,
					`"em_host":"wily.example.com"`))
			})

			It("opts file contains the credential from the wily user-provided binding", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "27_introscope_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dcom.wily.introscope.agentProfile.agent.enterpriseManager.host=wily.example.com"))
			})
		})

		Context("when Agent.jar is not present", func() {
			It("returns an error", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("introscope Agent.jar not found during finalize"))
			})
		})
	})
})
