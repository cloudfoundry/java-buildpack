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

func newSkyWalkingContext(buildDir, cacheDir, depsDir string) *common.Context {
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

// skyWalkingVCAPServices builds a VCAP_SERVICES JSON string for a SkyWalking service.
func skyWalkingVCAPServices(label, name string, tags []string, extraCreds string) string {
	tagJSON := "[]"
	if len(tags) > 0 {
		parts := make([]string, len(tags))
		for i, t := range tags {
			parts[i] = fmt.Sprintf("%q", t)
		}
		tagJSON = "[" + joinSWStrings(parts) + "]"
	}
	creds := `"placeholder":"true"`
	if extraCreds != "" {
		creds += "," + extraCreds
	}
	return fmt.Sprintf(`{%q:[{"name":%q,"label":%q,"tags":%s,"credentials":{%s}}]}`,
		label, name, label, tagJSON, creds)
}

func joinSWStrings(ss []string) string {
	result := ""
	for i, s := range ss {
		if i > 0 {
			result += ","
		}
		result += s
	}
	return result
}

// installSkyWalkingAgent creates the expected agent JAR structure under depsDir.
func installSkyWalkingAgent(depsDir string) {
	agentDir := filepath.Join(depsDir, "0", "sky_walking_agent", "skywalking-agent")
	Expect(os.MkdirAll(agentDir, 0755)).To(Succeed())
	Expect(os.WriteFile(filepath.Join(agentDir, "skywalking-agent.jar"), []byte("fake jar"), 0644)).To(Succeed())
}

var _ = Describe("SkyWalkingAgent", func() {
	var (
		fw       *frameworks.SkyWalkingAgentFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "sw-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "sw-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "sw-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewSkyWalkingAgentFramework(newSkyWalkingContext(buildDir, cacheDir, depsDir))
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(cacheDir)
		os.RemoveAll(depsDir)
		os.Unsetenv("SW_AGENT_COLLECTOR_BACKEND_SERVICES")
		os.Unsetenv("VCAP_SERVICES")
		os.Unsetenv("VCAP_APPLICATION")
		os.Unsetenv("JBP_CONFIG_SKY_WALKING_AGENT")
	})

	Describe("Detect", func() {
		Context("with no environment set", func() {
			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with SW_AGENT_COLLECTOR_BACKEND_SERVICES set", func() {
			BeforeEach(func() {
				os.Setenv("SW_AGENT_COLLECTOR_BACKEND_SERVICES", "skywalking-oap.example.com:11800")
			})

			It("returns 'SkyWalking'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("SkyWalking"))
			})
		})

		Context("with service bound by label 'skywalking'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", skyWalkingVCAPServices("skywalking", "my-sw", nil, ""))
			})

			It("returns 'SkyWalking'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("SkyWalking"))
			})
		})

		Context("with service tagged 'skywalking'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", skyWalkingVCAPServices("user-provided", "my-apm-svc", []string{"skywalking", "apm"}, ""))
			})

			It("returns 'SkyWalking'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("SkyWalking"))
			})
		})

		Context("with service name containing 'skywalking'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", skyWalkingVCAPServices("user-provided", "prod-skywalking-svc", nil, ""))
			})

			It("returns 'SkyWalking'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("SkyWalking"))
			})
		})

		Context("with an unrelated service bound", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", skyWalkingVCAPServices("newrelic", "my-newrelic", []string{"apm"}, ""))
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
				installSkyWalkingAgent(depsDir)
			})

			It("writes the opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "41_sky_walking_agent.opts")).To(BeAnExistingFile())
			})

			It("opts file contains -javaagent pointing to the runtime path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "41_sky_walking_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-javaagent:"))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/sky_walking_agent/skywalking-agent/skywalking-agent.jar"))
			})

			It("opts file does not embed the staging-time absolute path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "41_sky_walking_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(depsDir))
			})

			It("uses priority prefix 41 in the filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				entries, err := os.ReadDir(filepath.Join(depsDir, "0", "java_opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(entries).To(HaveLen(1))
				Expect(entries[0].Name()).To(Equal("41_sky_walking_agent.opts"))
			})
		})

		Context("with collector backend services from SW_AGENT_COLLECTOR_BACKEND_SERVICES", func() {
			BeforeEach(func() {
				installSkyWalkingAgent(depsDir)
				os.Setenv("SW_AGENT_COLLECTOR_BACKEND_SERVICES", "oap.example.com:11800")
			})

			It("opts file contains -Dskywalking.collector.backend_service", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "41_sky_walking_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dskywalking.collector.backend_service=oap.example.com:11800"))
			})
		})

		Context("with collector backend services from service binding (collector_backend_services key)", func() {
			BeforeEach(func() {
				installSkyWalkingAgent(depsDir)
				os.Setenv("VCAP_SERVICES", skyWalkingVCAPServices(
					"skywalking", "my-sw", nil,
					`"collector_backend_services":"oap-binding.example.com:11800"`,
				))
			})

			It("opts file contains -Dskywalking.collector.backend_service from binding", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "41_sky_walking_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dskywalking.collector.backend_service=oap-binding.example.com:11800"))
			})
		})

		Context("with collector backend services from service binding (collectorBackendServices camelCase key)", func() {
			BeforeEach(func() {
				installSkyWalkingAgent(depsDir)
				os.Setenv("VCAP_SERVICES", skyWalkingVCAPServices(
					"skywalking", "my-sw", nil,
					`"collectorBackendServices":"oap-camel.example.com:11800"`,
				))
			})

			It("opts file contains -Dskywalking.collector.backend_service from camelCase key", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "41_sky_walking_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dskywalking.collector.backend_service=oap-camel.example.com:11800"))
			})
		})

		Context("with collector backend services from service binding (backend_service key)", func() {
			BeforeEach(func() {
				installSkyWalkingAgent(depsDir)
				os.Setenv("VCAP_SERVICES", skyWalkingVCAPServices(
					"skywalking", "my-sw", nil,
					`"backend_service":"oap-short.example.com:11800"`,
				))
			})

			It("opts file contains -Dskywalking.collector.backend_service from backend_service key", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "41_sky_walking_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dskywalking.collector.backend_service=oap-short.example.com:11800"))
			})
		})

		Context("with SW_AGENT_COLLECTOR_BACKEND_SERVICES env var taking precedence over service binding", func() {
			BeforeEach(func() {
				installSkyWalkingAgent(depsDir)
				os.Setenv("SW_AGENT_COLLECTOR_BACKEND_SERVICES", "env-oap.example.com:11800")
				os.Setenv("VCAP_SERVICES", skyWalkingVCAPServices(
					"skywalking", "my-sw", nil,
					`"collector_backend_services":"binding-oap.example.com:11800"`,
				))
			})

			It("opts file uses the environment variable value", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "41_sky_walking_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("env-oap.example.com:11800"))
				Expect(string(content)).NotTo(ContainSubstring("binding-oap.example.com:11800"))
			})
		})

		Context("with VCAP_APPLICATION providing space:app_name", func() {
			BeforeEach(func() {
				installSkyWalkingAgent(depsDir)
				os.Setenv("VCAP_APPLICATION", `{"application_name":"my-app","space_name":"my-space"}`)
			})

			It("opts file contains -Dskywalking.agent.service_name with space:app format", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "41_sky_walking_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dskywalking.agent.service_name=my-space:my-app"))
			})
		})

		Context("with VCAP_APPLICATION providing only application_name (no space)", func() {
			BeforeEach(func() {
				installSkyWalkingAgent(depsDir)
				os.Setenv("VCAP_APPLICATION", `{"application_name":"standalone-app"}`)
			})

			It("opts file contains -Dskywalking.agent.service_name with app name only", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "41_sky_walking_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dskywalking.agent.service_name=standalone-app"))
			})
		})

		Context("with default_application_name set via JBP_CONFIG_SKY_WALKING_AGENT", func() {
			BeforeEach(func() {
				installSkyWalkingAgent(depsDir)
				os.Setenv("JBP_CONFIG_SKY_WALKING_AGENT", "default_application_name: config-app-name")
			})

			It("opts file contains -Dskywalking.agent.service_name from config", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "41_sky_walking_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dskywalking.agent.service_name=config-app-name"))
			})
		})

		Context("with VCAP_APPLICATION taking precedence over JBP_CONFIG_SKY_WALKING_AGENT", func() {
			BeforeEach(func() {
				installSkyWalkingAgent(depsDir)
				os.Setenv("VCAP_APPLICATION", `{"application_name":"vcap-app","space_name":"dev"}`)
				os.Setenv("JBP_CONFIG_SKY_WALKING_AGENT", "default_application_name: config-app-name")
			})

			It("opts file uses VCAP_APPLICATION value", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "41_sky_walking_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dskywalking.agent.service_name=dev:vcap-app"))
				Expect(string(content)).NotTo(ContainSubstring("config-app-name"))
			})
		})

		Context("with no app name or credentials", func() {
			BeforeEach(func() {
				installSkyWalkingAgent(depsDir)
			})

			It("opts file does not contain service_name or backend_service flags", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "41_sky_walking_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring("service_name"))
				Expect(string(content)).NotTo(ContainSubstring("backend_service"))
			})
		})

		Context("when the agent JAR is not present", func() {
			It("returns an error", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("agent jar path not found during finalize"))
			})
		})

		Context("with user-provided service binding containing skywalking in name", func() {
			BeforeEach(func() {
				installSkyWalkingAgent(depsDir)
				os.Setenv("VCAP_SERVICES", skyWalkingVCAPServices(
					"user-provided", "prod-skywalking", nil,
					`"collector_backend_services":"user-oap.example.com:11800"`,
				))
			})

			It("opts file contains backend_service from user-provided binding", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "41_sky_walking_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dskywalking.collector.backend_service=user-oap.example.com:11800"))
			})
		})

		Context("opts file uses $DEPS_DIR for runtime portability", func() {
			BeforeEach(func() {
				installSkyWalkingAgent(depsDir)
			})

			It("does not embed the staging-time absolute path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "41_sky_walking_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(depsDir))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR"))
			})
		})
	})
})
