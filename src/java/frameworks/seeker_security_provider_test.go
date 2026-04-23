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

func newSeekerContext(buildDir, cacheDir, depsDir string) *common.Context {
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

// seekerVCAPServices builds a VCAP_SERVICES JSON string for a Seeker service.
// extraCreds is optional comma-separated additional credential key:value pairs.
func seekerVCAPServices(label, name string, tags []string, serverURL, extraCreds string) string {
	tagJSON := "[]"
	if len(tags) > 0 {
		parts := make([]string, len(tags))
		for i, t := range tags {
			parts[i] = fmt.Sprintf("%q", t)
		}
		tagJSON = "[" + joinSeekerStrings(parts) + "]"
	}
	creds := fmt.Sprintf(`"seeker_server_url":%q`, serverURL)
	if extraCreds != "" {
		creds += "," + extraCreds
	}
	return fmt.Sprintf(`{%q:[{"name":%q,"label":%q,"tags":%s,"credentials":{%s}}]}`,
		label, name, label, tagJSON, creds)
}

func joinSeekerStrings(ss []string) string {
	result := ""
	for i, s := range ss {
		if i > 0 {
			result += ","
		}
		result += s
	}
	return result
}

// installSeekerAgent creates the expected seeker-agent.jar under depsDir.
func installSeekerAgent(depsDir string) {
	seekerDir := filepath.Join(depsDir, "0", "seeker_security_provider")
	Expect(os.MkdirAll(seekerDir, 0755)).To(Succeed())
	Expect(os.WriteFile(filepath.Join(seekerDir, "seeker-agent.jar"), []byte("fake jar"), 0644)).To(Succeed())
}

var _ = Describe("SeekerSecurityProvider", func() {
	var (
		fw       *frameworks.SeekerSecurityProviderFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "seeker-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "seeker-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "seeker-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewSeekerSecurityProviderFramework(newSeekerContext(buildDir, cacheDir, depsDir))
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

		Context("with service bound by label 'seeker' and seeker_server_url credential", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", seekerVCAPServices("seeker", "my-seeker", nil, "https://seeker.example.com", ""))
			})

			It("returns 'seeker-security-provider'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("seeker-security-provider"))
			})
		})

		Context("with service name containing 'seeker' and seeker_server_url credential", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", seekerVCAPServices("user-provided", "prod-seeker-svc", nil, "https://seeker.example.com", ""))
			})

			It("returns 'seeker-security-provider'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("seeker-security-provider"))
			})
		})

		Context("with service tagged 'seeker' and seeker_server_url credential", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", seekerVCAPServices("user-provided", "my-iast-svc", []string{"seeker", "security"}, "https://seeker.example.com", ""))
			})

			It("returns 'seeker-security-provider'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("seeker-security-provider"))
			})
		})

		Context("with seeker service bound but seeker_server_url is missing", func() {
			BeforeEach(func() {
				// Craft credentials without seeker_server_url
				os.Setenv("VCAP_SERVICES", `{"seeker":[{"name":"my-seeker","label":"seeker","tags":[],"credentials":{"other":"value"}}]}`)
			})

			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with seeker service bound but seeker_server_url is empty", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", seekerVCAPServices("seeker", "my-seeker", nil, "", ""))
			})

			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with an unrelated service bound", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", seekerVCAPServices("newrelic", "my-newrelic", []string{"apm"}, "https://nr.example.com", ""))
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

		Context("with case-insensitive label match 'Seeker'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", seekerVCAPServices("Seeker", "my-seeker", nil, "https://seeker.example.com", ""))
			})

			It("returns 'seeker-security-provider'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("seeker-security-provider"))
			})
		})
	})

	Describe("Finalize", func() {
		Context("with agent JAR present and valid service binding", func() {
			BeforeEach(func() {
				installSeekerAgent(depsDir)
				os.Setenv("VCAP_SERVICES", seekerVCAPServices("seeker", "my-seeker", nil, "https://seeker.example.com", ""))
			})

			It("writes the opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "40_seeker_security_provider.opts")).To(BeAnExistingFile())
			})

			It("opts file contains -javaagent pointing to the runtime seeker-agent.jar path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "40_seeker_security_provider.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-javaagent:"))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/seeker_security_provider/seeker-agent.jar"))
			})

			It("opts file does not embed the staging-time absolute path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "40_seeker_security_provider.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(depsDir))
			})

			It("uses priority prefix 40 in the filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				entries, err := os.ReadDir(filepath.Join(depsDir, "0", "java_opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(entries).To(HaveLen(1))
				Expect(entries[0].Name()).To(Equal("40_seeker_security_provider.opts"))
			})

			It("writes a profile.d script", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "profile.d", "seeker_security_provider.sh")).To(BeAnExistingFile())
			})

			It("profile.d script exports SEEKER_SERVER_URL", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "seeker_security_provider.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring(`export SEEKER_SERVER_URL="https://seeker.example.com"`))
			})
		})

		Context("with a different server URL", func() {
			BeforeEach(func() {
				installSeekerAgent(depsDir)
				os.Setenv("VCAP_SERVICES", seekerVCAPServices("seeker", "my-seeker", nil, "https://seeker-prod.corp.net:8080", ""))
			})

			It("profile.d script contains the correct server URL", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "seeker_security_provider.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("https://seeker-prod.corp.net:8080"))
			})
		})

		Context("with service detected via name pattern", func() {
			BeforeEach(func() {
				installSeekerAgent(depsDir)
				os.Setenv("VCAP_SERVICES", seekerVCAPServices("user-provided", "prod-seeker-iast", nil, "https://seeker.example.com", ""))
			})

			It("writes the opts file successfully", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "40_seeker_security_provider.opts")).To(BeAnExistingFile())
			})
		})

		Context("when VCAP_SERVICES is not set", func() {
			It("returns an error", func() {
				installSeekerAgent(depsDir)
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("Seeker service not found"))
			})
		})

		Context("when seeker_server_url is missing from credentials", func() {
			BeforeEach(func() {
				installSeekerAgent(depsDir)
				os.Setenv("VCAP_SERVICES", `{"seeker":[{"name":"my-seeker","label":"seeker","tags":[],"credentials":{"other":"value"}}]}`)
			})

			It("returns an error", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("seeker_server_url"))
			})
		})

		Context("when VCAP_SERVICES has no seeker service", func() {
			BeforeEach(func() {
				installSeekerAgent(depsDir)
				os.Setenv("VCAP_SERVICES", `{}`)
			})

			It("returns an error", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("Seeker service not found"))
			})
		})
	})
})
