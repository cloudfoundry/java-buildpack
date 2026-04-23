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

func newRiverbedContext(buildDir, cacheDir, depsDir string) *common.Context {
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

// riverbedVCAPServices builds a VCAP_SERVICES JSON string with optional extra credential fields.
func riverbedVCAPServices(label, name string, tags []string, extraCreds string) string {
	tagJSON := "[]"
	if len(tags) > 0 {
		parts := make([]string, len(tags))
		for i, t := range tags {
			parts[i] = fmt.Sprintf("%q", t)
		}
		tagJSON = "[" + joinStrings(parts) + "]"
	}
	baseCreds := `"uri":"riverbed://host"`
	if extraCreds != "" {
		baseCreds += "," + extraCreds
	}
	return fmt.Sprintf(`{%q:[{"name":%q,"label":%q,"tags":%s,"credentials":{%s}}]}`,
		label, name, label, tagJSON, baseCreds)
}

func joinStrings(ss []string) string {
	result := ""
	for i, s := range ss {
		if i > 0 {
			result += ","
		}
		result += s
	}
	return result
}

// installRiverbedAgent creates the expected agent JAR directory structure under depsDir.
func installRiverbedAgent(depsDir string) {
	libDir := filepath.Join(depsDir, "0", "riverbed_appinternals_agent", "lib")
	Expect(os.MkdirAll(libDir, 0755)).To(Succeed())
	Expect(os.WriteFile(filepath.Join(libDir, "rvbd-agent.jar"), []byte("fake jar"), 0644)).To(Succeed())
}

var _ = Describe("RiverbedAppInternalsAgent", func() {
	var (
		fw       *frameworks.RiverbedAppInternalsAgentFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "rvbd-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "rvbd-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "rvbd-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewRiverbedAppInternalsAgentFramework(newRiverbedContext(buildDir, cacheDir, depsDir))
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

		Context("with service bound by label 'riverbed-appinternals'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", riverbedVCAPServices("riverbed-appinternals", "my-rvbd", nil, ""))
			})

			It("returns 'riverbed-appinternals-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("riverbed-appinternals-agent"))
			})
		})

		Context("with service bound by label 'appinternals'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", riverbedVCAPServices("appinternals", "my-appinternals", nil, ""))
			})

			It("returns 'riverbed-appinternals-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("riverbed-appinternals-agent"))
			})
		})

		Context("with service tagged 'riverbed'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", riverbedVCAPServices("user-provided", "my-svc", []string{"riverbed", "apm"}, ""))
			})

			It("returns 'riverbed-appinternals-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("riverbed-appinternals-agent"))
			})
		})

		Context("with service tagged 'appinternals'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", riverbedVCAPServices("user-provided", "my-svc", []string{"appinternals"}, ""))
			})

			It("returns 'riverbed-appinternals-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("riverbed-appinternals-agent"))
			})
		})

		Context("with service name containing 'riverbed'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", riverbedVCAPServices("user-provided", "prod-riverbed-apm", nil, ""))
			})

			It("returns 'riverbed-appinternals-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("riverbed-appinternals-agent"))
			})
		})

		Context("with service name containing 'appinternals'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", riverbedVCAPServices("user-provided", "prod-appinternals-svc", nil, ""))
			})

			It("returns 'riverbed-appinternals-agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("riverbed-appinternals-agent"))
			})
		})

		Context("with an unrelated service bound", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", riverbedVCAPServices("newrelic", "my-newrelic", []string{"apm"}, ""))
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
		Context("when the agent JAR is present with no credentials", func() {
			BeforeEach(func() {
				installRiverbedAgent(depsDir)
			})

			It("writes the opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "37_riverbed_appinternals_agent.opts")).To(BeAnExistingFile())
			})

			It("opts file contains -javaagent pointing to the runtime path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "37_riverbed_appinternals_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-javaagent:"))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/riverbed_appinternals_agent/lib/rvbd-agent.jar"))
			})

			It("opts file does not embed the staging-time absolute path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "37_riverbed_appinternals_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(depsDir))
			})

			It("uses priority prefix 37 in the filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				entries, err := os.ReadDir(filepath.Join(depsDir, "0", "java_opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(entries).To(HaveLen(1))
				Expect(entries[0].Name()).To(Equal("37_riverbed_appinternals_agent.opts"))
			})
		})

		Context("when credentials include 'moniker'", func() {
			BeforeEach(func() {
				installRiverbedAgent(depsDir)
				os.Setenv("VCAP_SERVICES", riverbedVCAPServices(
					"riverbed-appinternals", "my-rvbd", nil,
					`"moniker":"my-app-name"`,
				))
			})

			It("opts file contains -Drvbd.moniker with the moniker value", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "37_riverbed_appinternals_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Drvbd.moniker=my-app-name"))
			})
		})

		Context("when credentials include 'rvbd_moniker'", func() {
			BeforeEach(func() {
				installRiverbedAgent(depsDir)
				os.Setenv("VCAP_SERVICES", riverbedVCAPServices(
					"riverbed-appinternals", "my-rvbd", nil,
					`"rvbd_moniker":"alt-moniker"`,
				))
			})

			It("opts file contains -Drvbd.moniker with the rvbd_moniker value", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "37_riverbed_appinternals_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Drvbd.moniker=alt-moniker"))
			})
		})

		Context("when no moniker credential but VCAP_APPLICATION has application_name", func() {
			BeforeEach(func() {
				installRiverbedAgent(depsDir)
				os.Setenv("VCAP_APPLICATION", `{"application_name":"vcap-app"}`)
			})

			It("opts file contains -Drvbd.moniker from VCAP_APPLICATION", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "37_riverbed_appinternals_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Drvbd.moniker=vcap-app"))
			})
		})

		Context("when credentials include 'analysis_server'", func() {
			BeforeEach(func() {
				installRiverbedAgent(depsDir)
				os.Setenv("VCAP_SERVICES", riverbedVCAPServices(
					"riverbed-appinternals", "my-rvbd", nil,
					`"analysis_server":"riverbed.example.com"`,
				))
			})

			It("opts file contains -Drvbd.analysis.server", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "37_riverbed_appinternals_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Drvbd.analysis.server=riverbed.example.com"))
			})
		})

		Context("when credentials include 'analysisServer' (camelCase)", func() {
			BeforeEach(func() {
				installRiverbedAgent(depsDir)
				os.Setenv("VCAP_SERVICES", riverbedVCAPServices(
					"riverbed-appinternals", "my-rvbd", nil,
					`"analysisServer":"camel.example.com"`,
				))
			})

			It("opts file contains -Drvbd.analysis.server from analysisServer key", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "37_riverbed_appinternals_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Drvbd.analysis.server=camel.example.com"))
			})
		})

		Context("when credentials include 'rvbd_analysis_server'", func() {
			BeforeEach(func() {
				installRiverbedAgent(depsDir)
				os.Setenv("VCAP_SERVICES", riverbedVCAPServices(
					"riverbed-appinternals", "my-rvbd", nil,
					`"rvbd_analysis_server":"rvbd.example.com"`,
				))
			})

			It("opts file contains -Drvbd.analysis.server from rvbd_analysis_server key", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "37_riverbed_appinternals_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Drvbd.analysis.server=rvbd.example.com"))
			})
		})

		Context("when no analysis_server credential is present", func() {
			BeforeEach(func() {
				installRiverbedAgent(depsDir)
			})

			It("opts file does not contain -Drvbd.analysis.server", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "37_riverbed_appinternals_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring("analysis.server"))
			})
		})

		Context("when the agent JAR is not present", func() {
			It("returns an error", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("agent jar not found"))
			})
		})
	})
})
