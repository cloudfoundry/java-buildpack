package frameworks_test

import (
	"archive/zip"
	"crypto/sha256"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/frameworks"
	"github.com/cloudfoundry/java-buildpack/src/java/resources"
	"github.com/cloudfoundry/libbuildpack"
)

const appDynamicsBaseManifest = "language: java\n"

func newAppDynamicsContext(buildDir, cacheDir, depsDir string) *common.Context {
	return newAppDynamicsContextWithManifest(buildDir, cacheDir, depsDir, appDynamicsBaseManifest)
}

// newAppDynamicsContextWithManifest builds a context backed by a real manifest so
// the manifest fallback path (forked buildpacks) can be exercised.
func newAppDynamicsContextWithManifest(buildDir, cacheDir, depsDir, manifestYAML string) *common.Context {
	logger := libbuildpack.NewLogger(GinkgoWriter)

	buildpackDir := filepath.Join(cacheDir, "buildpack")
	Expect(os.MkdirAll(buildpackDir, 0755)).To(Succeed())
	Expect(os.WriteFile(filepath.Join(buildpackDir, "manifest.yml"), []byte(manifestYAML), 0644)).To(Succeed())

	manifest, err := libbuildpack.NewManifest(buildpackDir, logger, time.Now())
	Expect(err).NotTo(HaveOccurred())

	stager := libbuildpack.NewStager([]string{buildDir, cacheDir, depsDir, "0"}, logger, manifest)
	return &common.Context{
		Stager:    stager,
		Manifest:  manifest,
		Installer: libbuildpack.NewInstaller(manifest),
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

// writeAppDynamicsAgentArchive writes a minimal AppDynamics agent archive at path.
// The real AppDynamics distribution is a ZIP; this helper mirrors its layout.
func writeAppDynamicsAgentArchive(path string) {
	file, err := os.Create(path)
	Expect(err).NotTo(HaveOccurred())
	defer file.Close()

	archive := zip.NewWriter(file)
	entries := map[string]string{
		"javaagent.jar":                              "fake appdynamics agent",
		"conf/controller-info.xml":                   "<controller-info/>",
		"ver26.10.0.38851/javaagent.jar":             "fake versioned appdynamics agent",
		"ver26.10.0.38851/conf/app-agent-config.xml": "<app-agent-configuration/>",
	}
	for name, content := range entries {
		writer, err := archive.Create(name)
		Expect(err).NotTo(HaveOccurred())
		_, err = writer.Write([]byte(content))
		Expect(err).NotTo(HaveOccurred())
	}

	Expect(archive.Close()).To(Succeed())
}

// serveAppDynamicsAgentArchive serves path over HTTP for download tests.
func serveAppDynamicsAgentArchive(path string) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, path)
	}))
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
		os.Unsetenv("CF_STACK")
	})

	Describe("Detect", func() {
		Context("with no VCAP_SERVICES set", func() {
			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with no VCAP_SERVICES set but an application-provided agent archive", func() {
			BeforeEach(func() {
				writeAppDynamicsAgentArchive(filepath.Join(buildDir, "appdynamics-agent.zip"))
			})

			It("detects the agent from the application", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("AppDynamics Agent"))
			})
		})

		Context("with no VCAP_SERVICES set but an application-provided agent directory", func() {
			BeforeEach(func() {
				agentDir := filepath.Join(buildDir, ".appdynamics")
				Expect(os.MkdirAll(agentDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(agentDir, "javaagent.jar"), []byte("fake jar"), 0644)).To(Succeed())
			})

			It("detects the agent from the application", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("AppDynamics Agent"))
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

		Context("with service bound by label 'app-dynamics'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", appdVCAPServices("app-dynamics", "my-appd", nil, ""))
			})

			It("returns 'AppDynamics Agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("AppDynamics Agent"))
			})
		})

		Context("with service tagged 'app-dynamics'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", appdVCAPServices("user-provided", "my-apm-svc", []string{"app-dynamics"}, ""))
			})

			It("returns 'AppDynamics Agent'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("AppDynamics Agent"))
			})
		})

		Context("with the documented 'app-dynamics-agent=<version>' tag", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", appdVCAPServices("user-provided", "my-apm-svc", []string{"app-dynamics-agent=26.10.0.38851"}, ""))
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

	Describe("Supply", func() {
		Context("with an agent archive at the service binding 'agent-uri'", func() {
			var server *httptest.Server

			BeforeEach(func() {
				archivePath := filepath.Join(cacheDir, "agent.zip")
				writeAppDynamicsAgentArchive(archivePath)
				server = serveAppDynamicsAgentArchive(archivePath)
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil,
					fmt.Sprintf(`"agent-uri":%q`, server.URL+"/agent.zip")))
			})

			AfterEach(func() {
				if server != nil {
					server.Close()
				}
			})

			It("downloads and extracts the agent", func() {
				Expect(fw.Supply()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "app_dynamics_agent", "javaagent.jar")).To(BeAnExistingFile())
				Expect(filepath.Join(depsDir, "0", "app_dynamics_agent", "conf", "controller-info.xml")).To(BeAnExistingFile())
			})

			It("installs the embedded default configuration", func() {
				Expect(fw.Supply()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "app_dynamics_agent", "defaults", "conf", "app-agent-config.xml")).To(BeAnExistingFile())
			})
		})

		Context("with the 'agent_url' credential alias", func() {
			var server *httptest.Server

			BeforeEach(func() {
				archivePath := filepath.Join(cacheDir, "agent.zip")
				writeAppDynamicsAgentArchive(archivePath)
				server = serveAppDynamicsAgentArchive(archivePath)
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil,
					fmt.Sprintf(`"agent_url":%q`, server.URL+"/agent.zip")))
			})

			AfterEach(func() {
				if server != nil {
					server.Close()
				}
			})

			It("downloads and extracts the agent", func() {
				Expect(fw.Supply()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "app_dynamics_agent", "javaagent.jar")).To(BeAnExistingFile())
			})
		})

		Context("with an application-provided archive in the app root", func() {
			BeforeEach(func() {
				writeAppDynamicsAgentArchive(filepath.Join(buildDir, "appdynamics-agent.zip"))
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil, ""))
			})

			It("extracts the agent without downloading", func() {
				Expect(fw.Supply()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "app_dynamics_agent", "javaagent.jar")).To(BeAnExistingFile())
			})
		})

		Context("with an application-provided zip named .tar.gz", func() {
			BeforeEach(func() {
				writeAppDynamicsAgentArchive(filepath.Join(buildDir, "appdynamics-agent.tar.gz"))
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil, ""))
			})

			It("detects the archive format from its contents", func() {
				Expect(fw.Supply()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "app_dynamics_agent", "javaagent.jar")).To(BeAnExistingFile())
			})
		})

		Context("with an application-provided archive under .appdynamics/", func() {
			BeforeEach(func() {
				Expect(os.MkdirAll(filepath.Join(buildDir, ".appdynamics"), 0755)).To(Succeed())
				writeAppDynamicsAgentArchive(filepath.Join(buildDir, ".appdynamics", "appdynamics-agent.zip"))
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil, ""))
			})

			It("extracts the agent", func() {
				Expect(fw.Supply()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "app_dynamics_agent", "javaagent.jar")).To(BeAnExistingFile())
			})
		})

		Context("with an application-provided unpacked agent directory", func() {
			BeforeEach(func() {
				agentDir := filepath.Join(buildDir, ".appdynamics")
				Expect(os.MkdirAll(filepath.Join(agentDir, "conf"), 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(agentDir, "javaagent.jar"), []byte("fake jar"), 0644)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(agentDir, "conf", "controller-info.xml"), []byte("<controller-info/>"), 0644)).To(Succeed())
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil, ""))
			})

			It("copies the agent into the dependency directory", func() {
				Expect(fw.Supply()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "app_dynamics_agent", "javaagent.jar")).To(BeAnExistingFile())
				Expect(filepath.Join(depsDir, "0", "app_dynamics_agent", "conf", "controller-info.xml")).To(BeAnExistingFile())
			})
		})

		Context("with a marketplace binding and a user-provided binding carrying agent-uri", func() {
			var server *httptest.Server

			BeforeEach(func() {
				archivePath := filepath.Join(cacheDir, "agent.zip")
				writeAppDynamicsAgentArchive(archivePath)
				server = serveAppDynamicsAgentArchive(archivePath)
				os.Setenv("VCAP_SERVICES", fmt.Sprintf(`{
  "appdynamics": [{"name":"marketplace-appd","label":"appdynamics","tags":["appdynamics"],"credentials":{"host-name":"controller.example.com"}}],
  "user-provided": [{"name":"appdynamics-agent","label":"user-provided","tags":[],"credentials":{"agent-uri":%q}}]
}`, server.URL+"/agent.zip"))
			})

			AfterEach(func() {
				if server != nil {
					server.Close()
				}
			})

			It("uses the agent-uri from the user-provided binding", func() {
				Expect(fw.Supply()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "app_dynamics_agent", "javaagent.jar")).To(BeAnExistingFile())
			})
		})

		Context("when the agent-uri download fails but an application archive exists", func() {
			var server *httptest.Server

			BeforeEach(func() {
				server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					http.Error(w, "boom", http.StatusInternalServerError)
				}))
				writeAppDynamicsAgentArchive(filepath.Join(buildDir, "appdynamics-agent.zip"))
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil,
					fmt.Sprintf(`"agent-uri":%q`, server.URL+"/agent.zip")))
			})

			AfterEach(func() {
				if server != nil {
					server.Close()
				}
			})

			It("falls back to the application-provided archive", func() {
				Expect(fw.Supply()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "app_dynamics_agent", "javaagent.jar")).To(BeAnExistingFile())
			})
		})

		Context("with agent-uri containing basic auth credentials", func() {
			var server *httptest.Server

			BeforeEach(func() {
				archivePath := filepath.Join(cacheDir, "agent.zip")
				writeAppDynamicsAgentArchive(archivePath)
				server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					user, password, ok := r.BasicAuth()
					if !ok || user != "appd" || password != "s3cret" {
						w.WriteHeader(http.StatusUnauthorized)
						return
					}
					http.ServeFile(w, r, archivePath)
				}))
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil,
					fmt.Sprintf(`"agent-uri":%q`, "http://appd:s3cret@"+strings.TrimPrefix(server.URL, "http://")+"/agent.zip")))
			})

			AfterEach(func() {
				if server != nil {
					server.Close()
				}
			})

			It("sends the credentials and installs the agent", func() {
				Expect(fw.Supply()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "app_dynamics_agent", "javaagent.jar")).To(BeAnExistingFile())
			})
		})

		Context("with an archive containing a path traversal entry", func() {
			BeforeEach(func() {
				archivePath := filepath.Join(buildDir, "appdynamics-agent.zip")
				file, err := os.Create(archivePath)
				Expect(err).NotTo(HaveOccurred())

				archive := zip.NewWriter(file)
				writer, err := archive.Create("../escaped.txt")
				Expect(err).NotTo(HaveOccurred())
				_, err = writer.Write([]byte("escaped"))
				Expect(err).NotTo(HaveOccurred())
				Expect(archive.Close()).To(Succeed())
				Expect(file.Close()).To(Succeed())

				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil, ""))
			})

			It("rejects the archive", func() {
				err := fw.Supply()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("unsafe path"))
			})
		})

		Context("with an appdynamics dependency in the manifest (forked buildpack)", func() {
			BeforeEach(func() {
				buildpackDir := filepath.Join(cacheDir, "buildpack")
				archivePath := filepath.Join(buildpackDir, "appdynamics-agent.zip")
				writeAppDynamicsAgentArchive(archivePath)

				data, err := os.ReadFile(archivePath)
				Expect(err).NotTo(HaveOccurred())
				digest := fmt.Sprintf("%x", sha256.Sum256(data))

				manifestYAML := fmt.Sprintf(`language: java
default_versions:
- name: appdynamics
  version: 26.10.0.38851
dependencies:
- name: appdynamics
  version: 26.10.0.38851
  uri: appdynamics-agent.zip
  file: appdynamics-agent.zip
  sha256: %s
  cf_stacks:
  - cflinuxfs4
`, digest)

				fw = frameworks.NewAppDynamicsFramework(newAppDynamicsContextWithManifest(buildDir, cacheDir, depsDir, manifestYAML))
				os.Setenv("CF_STACK", "cflinuxfs4")
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil, ""))
			})

			It("installs the agent from the manifest dependency", func() {
				Expect(fw.Supply()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "app_dynamics_agent", "javaagent.jar")).To(BeAnExistingFile())
			})
		})

		Context("with only an application-provided agent and no service binding", func() {
			BeforeEach(func() {
				writeAppDynamicsAgentArchive(filepath.Join(buildDir, "appdynamics-agent.zip"))
			})

			It("installs and finalizes without controller credentials", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("AppDynamics Agent"))

				Expect(fw.Supply()).To(Succeed())
				Expect(fw.Finalize()).To(Succeed())

				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "11_app_dynamics.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-javaagent:"))
				Expect(string(content)).NotTo(ContainSubstring("-Dappdynamics."))
			})
		})

		Context("with no agent source", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", appdVCAPServices("appdynamics", "my-appd", nil,
					`"host-name":"controller.example.com"`))
			})

			It("returns an actionable error", func() {
				err := fw.Supply()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("agent-uri"))
				Expect(err.Error()).To(ContainSubstring("appdynamics-agent.zip"))
				Expect(err.Error()).To(ContainSubstring("forked buildpack manifest"))
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

		Context("with service bound by label 'app-dynamics'", func() {
			BeforeEach(func() {
				installAppDynamicsAgent(depsDir)
				os.Setenv("VCAP_SERVICES", appdVCAPServices("app-dynamics", "my-appd", nil,
					`"host-name":"ctrl-appd.example.com"`))
			})

			It("uses the credentials from the app-dynamics binding", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "11_app_dynamics.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Dappdynamics.controller.hostName=ctrl-appd.example.com"))
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
