// Cloud Foundry Java Buildpack
// Copyright 2013-2026 the original author or authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package frameworks_test

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/frameworks"
	"github.com/cloudfoundry/libbuildpack"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("ElasticOtelJavaAgentFramework", func() {
	var (
		ctx       *common.Context
		framework *frameworks.ElasticOtelJavaAgentFramework
		tmpDir    string
		depsDir   string
	)

	BeforeEach(func() {
		var err error
		tmpDir, err = os.MkdirTemp("", "elastic-otel-javaagent-test-*")
		Expect(err).NotTo(HaveOccurred())

		depsDir = filepath.Join(tmpDir, "deps")
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		agentDir := filepath.Join(depsDir, "0", "elastic_otel_java_agent")
		Expect(os.MkdirAll(agentDir, 0755)).To(Succeed())
		Expect(os.WriteFile(
			filepath.Join(agentDir, "elastic-otel-javaagent-1.11.0.jar"),
			[]byte("fake jar"), 0644,
		)).To(Succeed())

		logger := libbuildpack.NewLogger(GinkgoWriter)
		manifest := &libbuildpack.Manifest{}
		stager := libbuildpack.NewStager([]string{tmpDir, "", depsDir, "0"}, logger, manifest)

		ctx = &common.Context{
			Stager:   stager,
			Manifest: manifest,
			Log:      logger,
		}
		framework = frameworks.NewElasticOtelJavaAgentFramework(ctx)
	})

	AfterEach(func() {
		os.RemoveAll(tmpDir)
		os.Unsetenv("VCAP_SERVICES")
		os.Unsetenv("VCAP_APPLICATION")
		os.Unsetenv("ELASTIC_OTEL_AGENT")
		os.Unsetenv("OTEL_EXPORTER_OTLP_ENDPOINT")
		os.Unsetenv("OTEL_EXPORTER_OTLP_HEADERS")
		os.Unsetenv("OTEL_SERVICE_NAME")
	})

	Describe("Detect", func() {
		It("does not detect without service binding or explicit environment", func() {
			name, err := framework.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(name).To(BeEmpty())
		})

		It("detects an elastic-otel service with endpoint and api key", func() {
			os.Setenv("VCAP_SERVICES", `{
				"elastic-otel": [{
					"name": "my-elastic-otel",
					"label": "elastic-otel",
					"tags": [],
					"credentials": {
						"otel.exporter.otlp.endpoint": "https://elastic.example.com:443",
						"api_key": "abc123"
					}
				}]
			}`)

			name, err := framework.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(name).To(Equal("elastic-otel-javaagent"))
		})

		It("detects a user-provided service tagged edot-java", func() {
			os.Setenv("VCAP_SERVICES", `{
				"user-provided": [{
					"name": "telemetry",
					"label": "user-provided",
					"tags": ["edot-java"],
					"credentials": {
						"endpoint": "https://elastic.example.com:443",
						"otel.exporter.otlp.headers": "Authorization=ApiKey abc123"
					}
				}]
			}`)

			name, err := framework.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(name).To(Equal("elastic-otel-javaagent"))
		})

		It("detects a service name containing elastic-otel", func() {
			os.Setenv("VCAP_SERVICES", `{
				"user-provided": [{
					"name": "prod-elastic-otel",
					"label": "user-provided",
					"tags": [],
					"credentials": {
						"otlp_endpoint": "https://elastic.example.com:443",
						"secret_token": "secret"
					}
				}]
			}`)

			name, err := framework.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(name).To(Equal("elastic-otel-javaagent"))
		})

		It("does not detect via ELASTIC_OTEL_AGENT without required configuration", func() {
			os.Setenv("ELASTIC_OTEL_AGENT", "true")
			name, err := framework.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(name).To(BeEmpty())
		})

		It("detects via ELASTIC_OTEL_AGENT with OTLP endpoint and headers", func() {
			os.Setenv("ELASTIC_OTEL_AGENT", "true")
			os.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "https://elastic.example.com:443")
			os.Setenv("OTEL_EXPORTER_OTLP_HEADERS", "Authorization=ApiKey abc123")
			name, err := framework.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(name).To(Equal("elastic-otel-javaagent"))
		})

		It("does not claim generic OTLP endpoint and headers configuration", func() {
			os.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "https://elastic.example.com:443")
			os.Setenv("OTEL_EXPORTER_OTLP_HEADERS", "Authorization=ApiKey abc123")
			name, err := framework.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(name).To(BeEmpty())
		})

		It("does not detect a generic OpenTelemetry collector service", func() {
			os.Setenv("VCAP_SERVICES", `{
				"otel-collector": [{
					"name": "my-otel",
					"label": "otel-collector",
					"tags": ["otel"],
					"credentials": {
						"endpoint": "http://collector:4318"
					}
				}]
			}`)

			name, err := framework.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(name).To(BeEmpty())
		})

		It("does not detect an Elastic APM service", func() {
			os.Setenv("VCAP_SERVICES", `{
				"elastic-apm": [{
					"name": "my-elastic-apm",
					"label": "elastic-apm",
					"tags": ["elastic-apm"],
					"credentials": {
						"server_url": "https://apm.example.com:8200",
						"secret_token": "secret"
					}
				}]
			}`)

			name, err := framework.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(name).To(BeEmpty())
		})

		It("does not detect an elastic-otel service missing authentication", func() {
			os.Setenv("VCAP_SERVICES", `{
				"elastic-otel": [{
					"name": "my-elastic-otel",
					"label": "elastic-otel",
					"tags": [],
					"credentials": {
						"endpoint": "https://elastic.example.com:443"
					}
				}]
			}`)

			name, err := framework.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(name).To(BeEmpty())
		})

		It("does not detect on OTLP endpoint environment variable alone", func() {
			os.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "https://elastic.example.com:443")
			name, err := framework.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(name).To(BeEmpty())
		})
	})

	Describe("Finalize", func() {
		optsFile := func() string {
			return filepath.Join(depsDir, "0", "java_opts", "44_elastic_otel_java_agent.opts")
		}
		profileFile := func() string {
			return filepath.Join(depsDir, "0", "profile.d", "elastic_otel_java_agent.sh")
		}

		It("writes javaagent configuration and resolves the API key header at runtime", func() {
			os.Setenv("VCAP_APPLICATION", `{"application_name":"my-cf-app","space_name":"production"}`)
			os.Setenv("VCAP_SERVICES", `{
				"elastic-otel": [{
					"name": "my-elastic-otel",
					"label": "elastic-otel",
					"tags": [],
					"credentials": {
						"otel.exporter.otlp.endpoint": "https://elastic.example.com:443",
						"api_key": "abc123",
						"elastic.otel.javaagent.log.level": "DEBUG"
					}
				}]
			}`)

			Expect(framework.Finalize()).To(Succeed())

			data, err := os.ReadFile(optsFile())
			Expect(err).NotTo(HaveOccurred())
			opts := string(data)
			Expect(opts).To(ContainSubstring("-javaagent:$DEPS_DIR/0/elastic_otel_java_agent/elastic-otel-javaagent-1.11.0.jar"))
			Expect(opts).To(ContainSubstring("-Dotel.exporter.otlp.endpoint=https://elastic.example.com:443"))
			Expect(opts).NotTo(ContainSubstring("otel.exporter.otlp.headers"))
			Expect(opts).NotTo(ContainSubstring("abc123"))
			Expect(opts).To(ContainSubstring("-Delastic.otel.javaagent.log.level=DEBUG"))
			Expect(opts).To(ContainSubstring("-Dotel.service.name=my-cf-app"))
			Expect(opts).To(ContainSubstring("-Dotel.resource.attributes='deployment.environment.name=production'"))
			Expect(opts).NotTo(ContainSubstring(tmpDir))

			data, err = os.ReadFile(profileFile())
			Expect(err).NotTo(HaveOccurred())
			profile := string(data)
			Expect(profile).To(ContainSubstring(`export OTEL_EXPORTER_OTLP_HEADERS="$elastic_otel_headers"`))
			Expect(profile).To(ContainSubstring(`"Authorization=ApiKey " + (.api_key | @uri)`))
			Expect(profile).To(ContainSubstring(`"$VCAP_SERVICES"`))
			Expect(profile).NotTo(ContainSubstring("abc123"))
		})

		It("uses explicit OTEL service configuration without copying headers into JAVA_OPTS", func() {
			os.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "https://env.elastic.example.com:443")
			os.Setenv("OTEL_EXPORTER_OTLP_HEADERS", "Authorization=ApiKey env-key")
			os.Setenv("OTEL_SERVICE_NAME", "env-service")

			Expect(framework.Finalize()).To(Succeed())

			data, err := os.ReadFile(optsFile())
			Expect(err).NotTo(HaveOccurred())
			opts := string(data)
			Expect(opts).To(ContainSubstring("-Dotel.exporter.otlp.endpoint=https://env.elastic.example.com:443"))
			Expect(opts).NotTo(ContainSubstring("otel.exporter.otlp.headers"))
			Expect(opts).NotTo(ContainSubstring("env-key"))
			Expect(opts).To(ContainSubstring("-Dotel.service.name=env-service"))

			data, err = os.ReadFile(profileFile())
			Expect(err).NotTo(HaveOccurred())
			Expect(string(data)).To(ContainSubstring(`[ -z "${OTEL_EXPORTER_OTLP_HEADERS:-}" ]`))
			Expect(string(data)).NotTo(ContainSubstring("env-key"))
		})

		It("resolves headers at runtime and prioritizes an explicit service label", func() {
			_, err := exec.LookPath("jq")
			Expect(err).NotTo(HaveOccurred(), "jq is required to resolve Elastic OTel headers at runtime")

			runtimeServices := `{
				"user-provided": [{
					"name": "first-elastic-otel-service",
					"label": "user-provided",
					"tags": [],
					"credentials": {"api_key": "wrong-key"}
				}],
				"elastic-otel": [{
					"name": "preferred-service",
					"label": "elastic-otel",
					"tags": [],
					"credentials": {"api_key": "right+key/=="}
				}]
			}`
			os.Setenv("VCAP_SERVICES", runtimeServices)
			Expect(framework.Finalize()).To(Succeed())

			cmd := exec.Command("bash", "-c", `. "$1"; printf '%s' "${OTEL_EXPORTER_OTLP_HEADERS:-}"`, "bash", profileFile())
			cmd.Env = []string{"PATH=" + os.Getenv("PATH"), "VCAP_SERVICES=" + runtimeServices}
			output, err := cmd.Output()
			Expect(err).NotTo(HaveOccurred())
			Expect(string(output)).To(Equal("Authorization=ApiKey right%2Bkey%2F%3D%3D"))
		})

		It("preserves an existing headers environment variable without requiring jq", func() {
			Expect(framework.Finalize()).To(Succeed())

			emptyPath := GinkgoT().TempDir()
			cmd := exec.Command("bash", "-c", `. "$1"; printf '%s' "$OTEL_EXPORTER_OTLP_HEADERS"`, "bash", profileFile())
			cmd.Env = []string{
				"PATH=" + emptyPath,
				"VCAP_SERVICES={invalid",
				"OTEL_EXPORTER_OTLP_HEADERS=Authorization=ApiKey existing-key",
			}
			output, err := cmd.Output()
			Expect(err).NotTo(HaveOccurred())
			Expect(string(output)).To(Equal("Authorization=ApiKey existing-key"))
		})

		It("warns but does not abort startup when jq is unavailable", func() {
			Expect(framework.Finalize()).To(Succeed())

			emptyPath := GinkgoT().TempDir()
			cmd := exec.Command("bash", "-e", "-c", `. "$1"; printf '%s' "${OTEL_EXPORTER_OTLP_HEADERS:-}"`, "bash", profileFile())
			cmd.Env = []string{"PATH=" + emptyPath, `VCAP_SERVICES={"elastic-otel":[]}`}
			var stderr bytes.Buffer
			cmd.Stderr = &stderr
			output, err := cmd.Output()
			Expect(err).NotTo(HaveOccurred())
			Expect(output).To(BeEmpty())
			Expect(stderr.String()).To(ContainSubstring("jq is not available"))
		})

		It("warns but does not abort startup when jq cannot parse VCAP_SERVICES", func() {
			Expect(framework.Finalize()).To(Succeed())

			cmd := exec.Command("bash", "-e", "-c", `jq() { return 2; }; . "$1"; printf '%s' "${OTEL_EXPORTER_OTLP_HEADERS:-}"`, "bash", profileFile())
			cmd.Env = []string{`VCAP_SERVICES={invalid`}
			var stderr bytes.Buffer
			cmd.Stderr = &stderr
			output, err := cmd.Output()
			Expect(err).NotTo(HaveOccurred())
			Expect(output).To(BeEmpty())
			Expect(stderr.String()).To(ContainSubstring("could not resolve OTLP headers from VCAP_SERVICES"))
		})

		It("preserves the service name configured by the service binding", func() {
			os.Setenv("OTEL_SERVICE_NAME", "env-service")
			os.Setenv("VCAP_SERVICES", `{
				"elastic-otel": [{
					"name": "my-elastic-otel",
					"label": "elastic-otel",
					"tags": [],
					"credentials": {
						"otel.exporter.otlp.endpoint": "https://elastic.example.com:443",
						"api_key": "abc123",
						"otel.service.name": "binding-service"
					}
				}]
			}`)

			Expect(framework.Finalize()).To(Succeed())

			data, err := os.ReadFile(optsFile())
			Expect(err).NotTo(HaveOccurred())
			opts := string(data)
			Expect(opts).To(ContainSubstring("-Dotel.service.name=binding-service"))
			Expect(opts).NotTo(ContainSubstring("-Dotel.service.name=env-service"))
		})
	})
})
