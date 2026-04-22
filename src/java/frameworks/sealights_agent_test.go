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

func newSealightsContext(buildDir, cacheDir, depsDir string) *common.Context {
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

// sealightsVCAPServices builds a minimal VCAP_SERVICES JSON for a Sealights service.
// extraCreds is a comma-separated list of additional JSON key:value pairs added to credentials.
func sealightsVCAPServices(label, name string, tags []string, token, extraCreds string) string {
	tagJSON := "[]"
	if len(tags) > 0 {
		parts := make([]string, len(tags))
		for i, t := range tags {
			parts[i] = fmt.Sprintf("%q", t)
		}
		tagJSON = "[" + joinSLStrings(parts) + "]"
	}
	creds := fmt.Sprintf(`"token":%q`, token)
	if extraCreds != "" {
		creds += "," + extraCreds
	}
	return fmt.Sprintf(`{%q:[{"name":%q,"label":%q,"tags":%s,"credentials":{%s}}]}`,
		label, name, label, tagJSON, creds)
}

func joinSLStrings(ss []string) string {
	result := ""
	for i, s := range ss {
		if i > 0 {
			result += ","
		}
		result += s
	}
	return result
}

// installSealightsAgent creates the expected agent JAR under depsDir.
func installSealightsAgent(depsDir, jarName string) {
	installDir := filepath.Join(depsDir, "0", "sealights_agent")
	Expect(os.MkdirAll(installDir, 0755)).To(Succeed())
	Expect(os.WriteFile(filepath.Join(installDir, jarName), []byte("fake jar"), 0644)).To(Succeed())
}

var _ = Describe("SealightsAgent", func() {
	var (
		fw       *frameworks.SealightsAgentFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "sl-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "sl-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "sl-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewSealightsAgentFramework(newSealightsContext(buildDir, cacheDir, depsDir))
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(cacheDir)
		os.RemoveAll(depsDir)
		os.Unsetenv("VCAP_SERVICES")
		os.Unsetenv("JBP_CONFIG_SEALIGHTS")
	})

	Describe("Detect", func() {
		Context("with no VCAP_SERVICES set", func() {
			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with service bound by label 'sealights'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", sealightsVCAPServices("sealights", "my-sl", nil, "tok", ""))
			})

			It("returns 'Sealights Agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Sealights Agent"))
			})
		})

		Context("with service tagged 'sealights'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", sealightsVCAPServices("user-provided", "my-svc", []string{"sealights", "testing"}, "tok", ""))
			})

			It("returns 'Sealights Agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Sealights Agent"))
			})
		})

		Context("with service name containing 'sealights'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", sealightsVCAPServices("user-provided", "prod-sealights-svc", nil, "tok", ""))
			})

			It("returns 'Sealights Agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Sealights Agent"))
			})
		})

		Context("with an unrelated service bound", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", sealightsVCAPServices("newrelic", "my-newrelic", []string{"apm"}, "tok", ""))
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
		Context("with exact agent JAR name (sl-test-listener.jar) and required token", func() {
			BeforeEach(func() {
				installSealightsAgent(depsDir, "sl-test-listener.jar")
				os.Setenv("VCAP_SERVICES", sealightsVCAPServices("sealights", "my-sl", nil, "secret-token", ""))
			})

			It("writes the opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "39_sealights_agent.opts")).To(BeAnExistingFile())
			})

			It("opts file contains -javaagent with $DEPS_DIR runtime path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "39_sealights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-javaagent:"))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/sealights_agent/sl-test-listener.jar"))
			})

			It("opts file contains -Dsl.token with the token value", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "39_sealights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dsl.token=secret-token"))
			})

			It("opts file contains -Dsl.log.folder pointing to $DEPS_DIR", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "39_sealights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dsl.log.folder=$DEPS_DIR/0/sealights_logs"))
			})

			It("creates the sealights_logs directory", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "sealights_logs")).To(BeADirectory())
			})

			It("opts file does not embed the staging-time absolute path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "39_sealights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(depsDir))
			})

			It("uses priority prefix 39 in the filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				entries, err := os.ReadDir(filepath.Join(depsDir, "0", "java_opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(entries).To(HaveLen(1))
				Expect(entries[0].Name()).To(Equal("39_sealights_agent.opts"))
			})
		})

		Context("with versioned JAR name (sl-test-listener-5.3.0.jar)", func() {
			BeforeEach(func() {
				installSealightsAgent(depsDir, "sl-test-listener-5.3.0.jar")
				os.Setenv("VCAP_SERVICES", sealightsVCAPServices("sealights", "my-sl", nil, "secret-token", ""))
			})

			It("resolves to the versioned JAR in the opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "39_sealights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("sl-test-listener-5.3.0.jar"))
			})
		})

		Context("with optional 'tags' credential", func() {
			BeforeEach(func() {
				installSealightsAgent(depsDir, "sl-test-listener.jar")
				os.Setenv("VCAP_SERVICES", sealightsVCAPServices("sealights", "my-sl", nil, "tok",
					`"tags":"env=prod,region=us"`))
			})

			It("opts file contains -Dsl.tags", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "39_sealights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dsl.tags=env=prod,region=us"))
			})
		})

		Context("with optional 'enableUpgrade' credential", func() {
			BeforeEach(func() {
				installSealightsAgent(depsDir, "sl-test-listener.jar")
				os.Setenv("VCAP_SERVICES", sealightsVCAPServices("sealights", "my-sl", nil, "tok",
					`"enableUpgrade":"true"`))
			})

			It("opts file contains -Dsl.enableUpgrade", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "39_sealights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dsl.enableUpgrade=true"))
			})
		})

		Context("with optional 'logLevel' credential", func() {
			BeforeEach(func() {
				installSealightsAgent(depsDir, "sl-test-listener.jar")
				os.Setenv("VCAP_SERVICES", sealightsVCAPServices("sealights", "my-sl", nil, "tok",
					`"logLevel":"DEBUG"`))
			})

			It("opts file contains -Dsl.log.level", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "39_sealights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dsl.log.level=DEBUG"))
			})
		})

		Context("with 'sl.proxy' credential", func() {
			BeforeEach(func() {
				installSealightsAgent(depsDir, "sl-test-listener.jar")
				os.Setenv("VCAP_SERVICES", sealightsVCAPServices("sealights", "my-sl", nil, "tok",
					`"sl.proxy":"http://proxy.example.com:8080"`))
			})

			It("opts file contains -Dsl.proxy from service credential", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "39_sealights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dsl.proxy=http://proxy.example.com:8080"))
			})
		})

		Context("with proxy set via JBP_CONFIG_SEALIGHTS (no service credential)", func() {
			BeforeEach(func() {
				installSealightsAgent(depsDir, "sl-test-listener.jar")
				os.Setenv("VCAP_SERVICES", sealightsVCAPServices("sealights", "my-sl", nil, "tok", ""))
				os.Setenv("JBP_CONFIG_SEALIGHTS", "proxy: http://cfg-proxy.example.com:3128")
			})

			It("opts file contains -Dsl.proxy from JBP_CONFIG_SEALIGHTS", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "39_sealights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dsl.proxy=http://cfg-proxy.example.com:3128"))
			})
		})

		Context("with 'sl.labId' credential", func() {
			BeforeEach(func() {
				installSealightsAgent(depsDir, "sl-test-listener.jar")
				os.Setenv("VCAP_SERVICES", sealightsVCAPServices("sealights", "my-sl", nil, "tok",
					`"sl.labId":"lab-42"`))
			})

			It("opts file contains -Dsl.labId from service credential", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "39_sealights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dsl.labId=lab-42"))
			})
		})

		Context("with lab_id set via JBP_CONFIG_SEALIGHTS (no service credential)", func() {
			BeforeEach(func() {
				installSealightsAgent(depsDir, "sl-test-listener.jar")
				os.Setenv("VCAP_SERVICES", sealightsVCAPServices("sealights", "my-sl", nil, "tok", ""))
				os.Setenv("JBP_CONFIG_SEALIGHTS", "lab_id: cfg-lab-99")
			})

			It("opts file contains -Dsl.labId from JBP_CONFIG_SEALIGHTS", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "39_sealights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dsl.labId=cfg-lab-99"))
			})
		})

		Context("with build_session_id set via JBP_CONFIG_SEALIGHTS", func() {
			BeforeEach(func() {
				installSealightsAgent(depsDir, "sl-test-listener.jar")
				os.Setenv("VCAP_SERVICES", sealightsVCAPServices("sealights", "my-sl", nil, "tok", ""))
				os.Setenv("JBP_CONFIG_SEALIGHTS", "build_session_id: bsid-abc123")
			})

			It("opts file contains -Dsl.buildSessionId", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "39_sealights_agent.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dsl.buildSessionId=bsid-abc123"))
			})
		})

		Context("when service credential token is missing", func() {
			BeforeEach(func() {
				installSealightsAgent(depsDir, "sl-test-listener.jar")
				// Manually craft a VCAP_SERVICES with no token field
				os.Setenv("VCAP_SERVICES", `{"sealights":[{"name":"my-sl","label":"sealights","tags":[],"credentials":{"other":"value"}}]}`)
			})

			It("returns an error", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("missing 'token' credential"))
			})
		})

		Context("when agent JAR is not present", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", sealightsVCAPServices("sealights", "my-sl", nil, "tok", ""))
			})

			It("returns an error", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("not found"))
			})
		})

		Context("when VCAP_SERVICES has no sealights service", func() {
			BeforeEach(func() {
				installSealightsAgent(depsDir, "sl-test-listener.jar")
				os.Setenv("VCAP_SERVICES", `{}`)
			})

			It("returns an error", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("sealights service not found"))
			})
		})
	})
})
