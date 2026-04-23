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

func newJacocoContext(buildDir, cacheDir, depsDir string) *common.Context {
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

// jacocoVCAPServices builds a VCAP_SERVICES JSON for a JaCoCo service.
// address is the required credential; extraCreds is an optional comma-separated
// list of additional JSON key:value pairs added to credentials.
func jacocoVCAPServices(label, name string, tags []string, address, extraCreds string) string {
	tagJSON := "[]"
	if len(tags) > 0 {
		parts := make([]string, len(tags))
		for i, t := range tags {
			parts[i] = fmt.Sprintf("%q", t)
		}
		tagJSON = "[" + joinJacocoStrings(parts) + "]"
	}
	creds := fmt.Sprintf(`"address":%q`, address)
	if extraCreds != "" {
		creds += "," + extraCreds
	}
	return fmt.Sprintf(`{%q:[{"name":%q,"label":%q,"tags":%s,"credentials":{%s}}]}`,
		label, name, label, tagJSON, creds)
}

func joinJacocoStrings(ss []string) string {
	result := ""
	for i, s := range ss {
		if i > 0 {
			result += ","
		}
		result += s
	}
	return result
}

// installJacocoAgent creates jacocoagent.jar at the expected path under depsDir.
func installJacocoAgent(depsDir string) {
	agentDir := filepath.Join(depsDir, "0", "jacoco_agent")
	Expect(os.MkdirAll(agentDir, 0755)).To(Succeed())
	Expect(os.WriteFile(filepath.Join(agentDir, "jacocoagent.jar"), []byte("fake jar"), 0644)).To(Succeed())
}

var _ = Describe("JaCoCo Agent", func() {
	var (
		fw       *frameworks.JacocoAgentFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "jacoco-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "jacoco-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "jacoco-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewJacocoAgentFramework(newJacocoContext(buildDir, cacheDir, depsDir))
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

		Context("with service bound by label 'jacoco' and address credential", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", jacocoVCAPServices("jacoco", "my-jacoco", nil, "localhost:6300", ""))
			})

			It("returns 'JaCoCo Agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("JaCoCo Agent"))
			})
		})

		Context("with service name containing 'jacoco' and address credential", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", jacocoVCAPServices("user-provided", "prod-jacoco-coverage", nil, "localhost:6300", ""))
			})

			It("returns 'JaCoCo Agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("JaCoCo Agent"))
			})
		})

		Context("with service bound by label 'jacoco' but address credential missing", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", `{"jacoco":[{"name":"my-jacoco","label":"jacoco","tags":[],"credentials":{"other":"value"}}]}`)
			})

			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with an unrelated service bound", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", jacocoVCAPServices("newrelic", "my-newrelic", []string{"apm"}, "some-addr", ""))
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
		Context("with agent JAR present and required address credential", func() {
			BeforeEach(func() {
				installJacocoAgent(depsDir)
				os.Setenv("VCAP_SERVICES", jacocoVCAPServices("jacoco", "my-jacoco", nil, "jacoco-server.example.com:6300", ""))
			})

			It("writes the opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "26_jacoco.opts")).To(BeAnExistingFile())
			})

			It("opts file contains -javaagent pointing to the runtime jacocoagent.jar path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "26_jacoco.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-javaagent:"))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/jacoco_agent/jacocoagent.jar"))
			})

			It("opts file does not embed the staging-time absolute path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "26_jacoco.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(depsDir))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR"))
			})

			It("uses priority prefix 26 in the filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				entries, err := os.ReadDir(filepath.Join(depsDir, "0", "java_opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(entries).To(HaveLen(1))
				Expect(entries[0].Name()).To(Equal("26_jacoco.opts"))
			})

			It("opts file contains address property", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "26_jacoco.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("address=jacoco-server.example.com:6300"))
			})

			It("opts file contains default output=tcpclient", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "26_jacoco.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("output=tcpclient"))
			})

			It("opts file contains sessionid=$CF_INSTANCE_GUID", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "26_jacoco.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("sessionid=$CF_INSTANCE_GUID"))
			})
		})

		Context("with optional 'excludes' credential", func() {
			BeforeEach(func() {
				installJacocoAgent(depsDir)
				os.Setenv("VCAP_SERVICES", jacocoVCAPServices("jacoco", "my-jacoco", nil, "host:6300",
					`"excludes":"com.example.generated.*"`))
			})

			It("opts file contains excludes property", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "26_jacoco.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("excludes=com.example.generated.*"))
			})
		})

		Context("with optional 'includes' credential", func() {
			BeforeEach(func() {
				installJacocoAgent(depsDir)
				os.Setenv("VCAP_SERVICES", jacocoVCAPServices("jacoco", "my-jacoco", nil, "host:6300",
					`"includes":"com.example.*"`))
			})

			It("opts file contains includes property", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "26_jacoco.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("includes=com.example.*"))
			})
		})

		Context("with optional 'port' credential", func() {
			BeforeEach(func() {
				installJacocoAgent(depsDir)
				os.Setenv("VCAP_SERVICES", jacocoVCAPServices("jacoco", "my-jacoco", nil, "host:6300",
					`"port":"6301"`))
			})

			It("opts file contains port property", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "26_jacoco.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("port=6301"))
			})
		})

		Context("with optional 'output' credential overriding the default", func() {
			BeforeEach(func() {
				installJacocoAgent(depsDir)
				os.Setenv("VCAP_SERVICES", jacocoVCAPServices("jacoco", "my-jacoco", nil, "host:6300",
					`"output":"file"`))
			})

			It("opts file contains the overridden output property", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "26_jacoco.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("output=file"))
				Expect(string(content)).NotTo(ContainSubstring("output=tcpclient"))
			})
		})

		Context("with service detected via name pattern", func() {
			BeforeEach(func() {
				installJacocoAgent(depsDir)
				os.Setenv("VCAP_SERVICES", jacocoVCAPServices("user-provided", "prod-jacoco-svc", nil, "host:6300", ""))
			})

			It("writes the opts file successfully", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "26_jacoco.opts")).To(BeAnExistingFile())
			})
		})

		Context("when VCAP_SERVICES has no jacoco service", func() {
			BeforeEach(func() {
				installJacocoAgent(depsDir)
				os.Setenv("VCAP_SERVICES", `{}`)
			})

			It("returns an error", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("JaCoCo service binding not found"))
			})
		})

		Context("when address credential is missing", func() {
			BeforeEach(func() {
				installJacocoAgent(depsDir)
				os.Setenv("VCAP_SERVICES", `{"jacoco":[{"name":"my-jacoco","label":"jacoco","tags":[],"credentials":{"other":"value"}}]}`)
			})

			It("returns an error", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("address"))
			})
		})

		Context("when jacocoagent.jar is not present", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", jacocoVCAPServices("jacoco", "my-jacoco", nil, "host:6300", ""))
			})

			It("returns an error", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("jacocoagent.jar"))
			})
		})

		Context("with jacocoagent.jar installed under a lib subdirectory", func() {
			BeforeEach(func() {
				libDir := filepath.Join(depsDir, "0", "jacoco_agent", "lib")
				Expect(os.MkdirAll(libDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(libDir, "jacocoagent.jar"), []byte("fake jar"), 0644)).To(Succeed())
				os.Setenv("VCAP_SERVICES", jacocoVCAPServices("jacoco", "my-jacoco", nil, "host:6300", ""))
			})

			It("resolves the JAR from the lib subdirectory", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "26_jacoco.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/jacoco_agent/lib/jacocoagent.jar"))
			})
		})
	})
})
