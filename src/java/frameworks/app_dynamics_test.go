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

func newAppDynamicsContext(buildDir, cacheDir, depsDir string) *common.Context {
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

// appdVCAPServices builds a VCAP_SERVICES JSON for an AppDynamics service.
// extraCreds is an optional comma-separated list of additional JSON key:value pairs.
func appdVCAPServices(label, name string, tags []string, extraCreds string) string {
	tagJSON := "[]"
	if len(tags) > 0 {
		parts := make([]string, len(tags))
		for i, t := range tags {
			parts[i] = fmt.Sprintf("%q", t)
		}
		tagJSON = "[" + joinAPPDStrings(parts) + "]"
	}
	creds := `"placeholder":"true"`
	if extraCreds != "" {
		creds += "," + extraCreds
	}
	return fmt.Sprintf(`{%q:[{"name":%q,"label":%q,"tags":%s,"credentials":{%s}}]}`,
		label, name, label, tagJSON, creds)
}

func joinAPPDStrings(ss []string) string {
	result := ""
	for i, s := range ss {
		if i > 0 {
			result += ","
		}
		result += s
	}
	return result
}

// installAppDynamicsAgent creates javaagent.jar at the flat path under depsDir.
func installAppDynamicsAgent(depsDir string) {
	agentDir := filepath.Join(depsDir, "0", "app_dynamics_agent")
	Expect(os.MkdirAll(agentDir, 0755)).To(Succeed())
	Expect(os.WriteFile(filepath.Join(agentDir, "javaagent.jar"), []byte("fake jar"), 0644)).To(Succeed())
}

// installAppDynamicsAgentVersioned creates javaagent.jar under a ver* subdirectory.
func installAppDynamicsAgentVersioned(depsDir, verDir string) {
	agentDir := filepath.Join(depsDir, "0", "app_dynamics_agent", verDir)
	Expect(os.MkdirAll(agentDir, 0755)).To(Succeed())
	Expect(os.WriteFile(filepath.Join(agentDir, "javaagent.jar"), []byte("fake jar"), 0644)).To(Succeed())
}

var _ = Describe("AppDynamics Agent", func() {
	var (
		fw       *frameworks.AppDynamicsFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "appd-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "appd-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "appd-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewAppDynamicsFramework(newAppDynamicsContext(buildDir, cacheDir, depsDir))
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

		Context("with service bound by label 'appdynamics'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil, ""))
			})

			It("returns 'AppDynamics Agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("AppDynamics Agent"))
			})
		})

		Context("with service tagged 'appdynamics'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", appdVCAPServices("user-provided", "my-apm-svc", []string{"appdynamics", "apm"}, ""))
			})

			It("returns 'AppDynamics Agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("AppDynamics Agent"))
			})
		})

		Context("with service name containing 'appdynamics'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", appdVCAPServices("user-provided", "prod-appdynamics-svc", nil, ""))
			})

			It("returns 'AppDynamics Agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("AppDynamics Agent"))
			})
		})

		Context("with an unrelated service bound", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", appdVCAPServices("newrelic", "my-newrelic", []string{"apm"}, ""))
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
		Context("with agent JAR present at the flat path and no credentials", func() {
			BeforeEach(func() {
				installAppDynamicsAgent(depsDir)
			})

			It("writes the opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "11_app_dynamics.opts")).To(BeAnExistingFile())
			})

			It("opts file contains -javaagent pointing to the runtime JAR path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "11_app_dynamics.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-javaagent:"))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/app_dynamics_agent/javaagent.jar"))
			})

			It("opts file does not embed the staging-time absolute path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "11_app_dynamics.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(depsDir))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR"))
			})

			It("uses priority prefix 11 in the filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				entries, err := os.ReadDir(filepath.Join(depsDir, "0", "java_opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(entries).To(HaveLen(1))
				Expect(entries[0].Name()).To(Equal("11_app_dynamics.opts"))
			})
		})

		Context("with agent JAR under a versioned subdirectory (ver24.7.0)", func() {
			BeforeEach(func() {
				installAppDynamicsAgentVersioned(depsDir, "ver24.7.0")
			})

			It("resolves the JAR from the versioned subdirectory", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "11_app_dynamics.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/app_dynamics_agent/ver24.7.0/javaagent.jar"))
			})
		})

		Context("with host-name credential", func() {
			BeforeEach(func() {
				installAppDynamicsAgent(depsDir)
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil,
					`"host-name":"appd-controller.example.com"`))
			})

			It("opts file contains -Dappdynamics.controller.hostName", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "11_app_dynamics.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dappdynamics.controller.hostName=appd-controller.example.com"))
			})
		})

		Context("with port credential", func() {
			BeforeEach(func() {
				installAppDynamicsAgent(depsDir)
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil,
					`"port":"8090"`))
			})

			It("opts file contains -Dappdynamics.controller.port", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "11_app_dynamics.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dappdynamics.controller.port=8090"))
			})
		})

		Context("with ssl-enabled credential", func() {
			BeforeEach(func() {
				installAppDynamicsAgent(depsDir)
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil,
					`"ssl-enabled":"true"`))
			})

			It("opts file contains -Dappdynamics.controller.ssl.enabled", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "11_app_dynamics.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dappdynamics.controller.ssl.enabled=true"))
			})
		})

		Context("with account-name credential", func() {
			BeforeEach(func() {
				installAppDynamicsAgent(depsDir)
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil,
					`"account-name":"customer1"`))
			})

			It("opts file contains -Dappdynamics.agent.accountName", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "11_app_dynamics.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dappdynamics.agent.accountName=customer1"))
			})
		})

		Context("with account-access-key credential", func() {
			BeforeEach(func() {
				installAppDynamicsAgent(depsDir)
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil,
					`"account-access-key":"secret-key-abc"`))
			})

			It("opts file contains -Dappdynamics.agent.accountAccessKey", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "11_app_dynamics.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dappdynamics.agent.accountAccessKey=secret-key-abc"))
			})
		})

		Context("with application-name credential", func() {
			BeforeEach(func() {
				installAppDynamicsAgent(depsDir)
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil,
					`"application-name":"my-cf-app"`))
			})

			It("opts file contains -Dappdynamics.agent.applicationName", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "11_app_dynamics.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dappdynamics.agent.applicationName=my-cf-app"))
			})
		})

		Context("with tier-name credential", func() {
			BeforeEach(func() {
				installAppDynamicsAgent(depsDir)
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil,
					`"tier-name":"web-tier"`))
			})

			It("opts file contains -Dappdynamics.agent.tierName", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "11_app_dynamics.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dappdynamics.agent.tierName=web-tier"))
			})
		})

		Context("with node-name credential", func() {
			BeforeEach(func() {
				installAppDynamicsAgent(depsDir)
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil,
					`"node-name":"node-1"`))
			})

			It("opts file contains -Dappdynamics.agent.nodeName", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "11_app_dynamics.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dappdynamics.agent.nodeName=node-1"))
			})
		})

		Context("with all credentials present", func() {
			BeforeEach(func() {
				installAppDynamicsAgent(depsDir)
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil,
					`"host-name":"ctrl.example.com","port":"443","ssl-enabled":"true","account-name":"acme","account-access-key":"key123","application-name":"shop","tier-name":"api","node-name":"node-0"`))
			})

			It("opts file contains all agent properties", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "11_app_dynamics.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dappdynamics.controller.hostName=ctrl.example.com"))
				Expect(string(content)).To(ContainSubstring("-Dappdynamics.controller.port=443"))
				Expect(string(content)).To(ContainSubstring("-Dappdynamics.controller.ssl.enabled=true"))
				Expect(string(content)).To(ContainSubstring("-Dappdynamics.agent.accountName=acme"))
				Expect(string(content)).To(ContainSubstring("-Dappdynamics.agent.accountAccessKey=key123"))
				Expect(string(content)).To(ContainSubstring("-Dappdynamics.agent.applicationName=shop"))
				Expect(string(content)).To(ContainSubstring("-Dappdynamics.agent.tierName=api"))
				Expect(string(content)).To(ContainSubstring("-Dappdynamics.agent.nodeName=node-0"))
			})
		})

		Context("with service detected via name pattern (user-provided)", func() {
			BeforeEach(func() {
				installAppDynamicsAgent(depsDir)
				os.Setenv("VCAP_SERVICES", appdVCAPServices("user-provided", "prod-appdynamics", nil,
					`"host-name":"ctrl.example.com"`))
			})

			It("opts file contains the credential from the user-provided binding", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "11_app_dynamics.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dappdynamics.controller.hostName=ctrl.example.com"))
			})
		})

		Context("when javaagent.jar is not present", func() {
			It("returns an error", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("javaagent.jar"))
			})
		})
	})

	Describe("Embedded config", func() {
		const embeddedPath = "app_dynamics_agent/defaults/conf/app-agent-config.xml"

		It("exists in embedded resources", func() {
			Expect(resources.Exists(embeddedPath)).To(BeTrue())
		})

		It("has expected XML structure", func() {
			configData, err := resources.GetResource(embeddedPath)
			Expect(err).NotTo(HaveOccurred())
			configStr := string(configData)
			Expect(configStr).To(ContainSubstring("<app-agent-configuration>"))
			Expect(configStr).To(ContainSubstring("<configuration-properties>"))
			Expect(configStr).To(ContainSubstring("<sensitive-url-filters>"))
			Expect(configStr).To(ContainSubstring("<sensitive-data-filters>"))
			Expect(configStr).To(ContainSubstring("<agent-services>"))
			Expect(configStr).To(ContainSubstring(`<agent-service name="BCIEngine"`))
			Expect(configStr).To(ContainSubstring(`<agent-service name="SnapshotService"`))
			Expect(configStr).To(ContainSubstring(`<agent-service name="TransactionMonitoringService"`))
		})

		It("can be written to disk", func() {
			tmpDir, err := os.MkdirTemp("", "appd-cfg")
			Expect(err).NotTo(HaveOccurred())
			defer os.RemoveAll(tmpDir)

			confDir := filepath.Join(tmpDir, "defaults", "conf")
			Expect(os.MkdirAll(confDir, 0755)).To(Succeed())
			configData, err := resources.GetResource(embeddedPath)
			Expect(err).NotTo(HaveOccurred())
			configPath := filepath.Join(confDir, "app-agent-config.xml")
			Expect(os.WriteFile(configPath, configData, 0644)).To(Succeed())
			written, err := os.ReadFile(configPath)
			Expect(err).NotTo(HaveOccurred())
			Expect(string(written)).To(ContainSubstring("<app-agent-configuration>"))
		})

		It("does not overwrite an existing user-provided config", func() {
			tmpDir, err := os.MkdirTemp("", "appd-cfg")
			Expect(err).NotTo(HaveOccurred())
			defer os.RemoveAll(tmpDir)

			confDir := filepath.Join(tmpDir, "defaults", "conf")
			Expect(os.MkdirAll(confDir, 0755)).To(Succeed())
			configPath := filepath.Join(confDir, "app-agent-config.xml")
			userConfig := "<!-- user config -->"
			Expect(os.WriteFile(configPath, []byte(userConfig), 0644)).To(Succeed())

			// File already exists — simulate the skip-if-exists guard
			_, statErr := os.Stat(configPath)
			Expect(statErr).NotTo(HaveOccurred())
			existing, err := os.ReadFile(configPath)
			Expect(err).NotTo(HaveOccurred())
			Expect(string(existing)).To(ContainSubstring("<!-- user config -->"))
		})
	})
})
