package frameworks_test

import (
	"os"
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

		It("detects via ELASTIC_OTEL_AGENT", func() {
			os.Setenv("ELASTIC_OTEL_AGENT", "true")
			name, err := framework.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(name).To(Equal("elastic-otel-javaagent"))
		})

		It("detects via OTLP endpoint and headers environment variables", func() {
			os.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "https://elastic.example.com:443")
			os.Setenv("OTEL_EXPORTER_OTLP_HEADERS", "Authorization=ApiKey abc123")
			name, err := framework.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(name).To(Equal("elastic-otel-javaagent"))
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

		It("writes javaagent, endpoint, derived API key header, and application service name", func() {
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
			Expect(opts).To(ContainSubstring("-Dotel.exporter.otlp.headers='Authorization=ApiKey abc123'"))
			Expect(opts).To(ContainSubstring("-Delastic.otel.javaagent.log.level=DEBUG"))
			Expect(opts).To(ContainSubstring("-Dotel.service.name=my-cf-app"))
			Expect(opts).To(ContainSubstring("-Dotel.resource.attributes=deployment.environment.name=production"))
			Expect(opts).NotTo(ContainSubstring(tmpDir))
		})

		It("uses explicit OTEL_SERVICE_NAME and OTEL_EXPORTER_OTLP_HEADERS environment values", func() {
			os.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "https://env.elastic.example.com:443")
			os.Setenv("OTEL_EXPORTER_OTLP_HEADERS", "Authorization=ApiKey env-key")
			os.Setenv("OTEL_SERVICE_NAME", "env-service")

			Expect(framework.Finalize()).To(Succeed())

			data, err := os.ReadFile(optsFile())
			Expect(err).NotTo(HaveOccurred())
			opts := string(data)
			Expect(opts).To(ContainSubstring("-Dotel.exporter.otlp.endpoint=https://env.elastic.example.com:443"))
			Expect(opts).To(ContainSubstring("-Dotel.exporter.otlp.headers='Authorization=ApiKey env-key'"))
			Expect(opts).To(ContainSubstring("-Dotel.service.name=env-service"))
		})
	})
})
