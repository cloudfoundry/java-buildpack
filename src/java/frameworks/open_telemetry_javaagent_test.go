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

var _ = Describe("OpenTelemetryJavaagentFramework", func() {
	var (
		ctx       *common.Context
		framework *frameworks.OpenTelemetryJavaagentFramework
		tmpDir    string
		depsDir   string
	)

	BeforeEach(func() {
		var err error
		tmpDir, err = os.MkdirTemp("", "otel-javaagent-test-*")
		Expect(err).NotTo(HaveOccurred())

		depsDir = filepath.Join(tmpDir, "deps")
		err = os.MkdirAll(filepath.Join(depsDir, "0"), 0755)
		Expect(err).NotTo(HaveOccurred())

		logger := libbuildpack.NewLogger(os.Stdout)
		manifest := &libbuildpack.Manifest{}
		stager := libbuildpack.NewStager([]string{tmpDir, "", depsDir, "0"}, logger, manifest)

		ctx = &common.Context{
			Stager:   stager,
			Manifest: manifest,
			Log:      logger,
		}

		framework = frameworks.NewOpenTelemetryJavaagentFramework(ctx)
	})

	AfterEach(func() {
		os.RemoveAll(tmpDir)
		os.Unsetenv("VCAP_SERVICES")
	})

	Describe("Detect", func() {
		Context("without any service binding", func() {
			It("does not detect", func() {
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with otel-collector service label", func() {
			It("detects successfully", func() {
				os.Setenv("VCAP_SERVICES", `{
					"otel-collector": [{
						"name": "my-otel",
						"label": "otel-collector",
						"tags": [],
						"credentials": {"endpoint": "http://collector:4318"}
					}]
				}`)
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("OpenTelemetry Javaagent"))
			})
		})

		Context("with opentelemetry service label", func() {
			It("detects successfully", func() {
				os.Setenv("VCAP_SERVICES", `{
					"opentelemetry": [{
						"name": "my-otel",
						"label": "opentelemetry",
						"tags": [],
						"credentials": {}
					}]
				}`)
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("OpenTelemetry Javaagent"))
			})
		})

		Context("with otel tag", func() {
			It("detects via tag", func() {
				os.Setenv("VCAP_SERVICES", `{
					"user-provided": [{
						"name": "my-collector",
						"label": "user-provided",
						"tags": ["otel"],
						"credentials": {}
					}]
				}`)
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("OpenTelemetry Javaagent"))
			})
		})

		Context("with opentelemetry tag", func() {
			It("detects via tag", func() {
				os.Setenv("VCAP_SERVICES", `{
					"user-provided": [{
						"name": "my-collector",
						"label": "user-provided",
						"tags": ["opentelemetry"],
						"credentials": {}
					}]
				}`)
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("OpenTelemetry Javaagent"))
			})
		})

		Context("with otel-collector tag", func() {
			It("detects via tag", func() {
				os.Setenv("VCAP_SERVICES", `{
					"user-provided": [{
						"name": "my-collector",
						"label": "user-provided",
						"tags": ["otel-collector"],
						"credentials": {}
					}]
				}`)
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("OpenTelemetry Javaagent"))
			})
		})

		Context("with user-provided service matching otel-collector name pattern", func() {
			It("detects via name pattern", func() {
				os.Setenv("VCAP_SERVICES", `{
					"user-provided": [{
						"name": "my-otel-collector",
						"label": "user-provided",
						"tags": [],
						"credentials": {}
					}]
				}`)
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("OpenTelemetry Javaagent"))
			})
		})

		Context("with user-provided service matching otel name pattern", func() {
			It("detects via name pattern", func() {
				os.Setenv("VCAP_SERVICES", `{
					"user-provided": [{
						"name": "my-otel-sidecar",
						"label": "user-provided",
						"tags": [],
						"credentials": {}
					}]
				}`)
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("OpenTelemetry Javaagent"))
			})
		})

		Context("with unrelated service binding", func() {
			It("does not detect", func() {
				os.Setenv("VCAP_SERVICES", `{
					"newrelic": [{
						"name": "newrelic-service",
						"label": "newrelic",
						"tags": ["apm"],
						"credentials": {"licenseKey": "key"}
					}]
				}`)
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with invalid VCAP_SERVICES JSON", func() {
			It("does not detect and does not error", func() {
				os.Setenv("VCAP_SERVICES", `{invalid}`)
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})
	})

	Describe("Finalize", func() {
		otelOptsFile := func() string {
			return filepath.Join(depsDir, "0", "java_opts", "36_open_telemetry_javaagent.opts")
		}

		Context("with otel-collector service and otel.* credentials", func() {
			It("writes javaagent and otel.* properties to opts file", func() {
				os.Setenv("VCAP_SERVICES", `{
					"otel-collector": [{
						"name": "my-otel",
						"label": "otel-collector",
						"tags": [],
						"credentials": {
							"otel.exporter.otlp.endpoint": "http://collector:4318",
							"otel.traces.sampler": "always_on"
						}
					}]
				}`)

				err := framework.Finalize()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(otelOptsFile())
				Expect(err).NotTo(HaveOccurred())
				opts := string(data)

				Expect(opts).To(ContainSubstring("-javaagent:$DEPS_DIR/0/open_telemetry_javaagent/opentelemetry-javaagent.jar"))
				Expect(opts).To(ContainSubstring("-Dotel.exporter.otlp.endpoint=http://collector:4318"))
				Expect(opts).To(ContainSubstring("-Dotel.traces.sampler=always_on"))
			})
		})

		Context("with credentials that do not start with otel.", func() {
			It("does not include non-otel credentials as JVM properties", func() {
				os.Setenv("VCAP_SERVICES", `{
					"otel-collector": [{
						"name": "my-otel",
						"label": "otel-collector",
						"tags": [],
						"credentials": {
							"otel.exporter.otlp.endpoint": "http://collector:4318",
							"username": "admin",
							"password": "secret"
						}
					}]
				}`)

				err := framework.Finalize()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(otelOptsFile())
				Expect(err).NotTo(HaveOccurred())
				opts := string(data)

				Expect(opts).NotTo(ContainSubstring("-Dusername="))
				Expect(opts).NotTo(ContainSubstring("-Dpassword="))
				Expect(opts).To(ContainSubstring("-Dotel.exporter.otlp.endpoint=http://collector:4318"))
			})
		})

		Context("without a service binding", func() {
			It("writes only the javaagent flag", func() {
				err := framework.Finalize()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(otelOptsFile())
				Expect(err).NotTo(HaveOccurred())
				opts := string(data)

				Expect(opts).To(ContainSubstring("-javaagent:$DEPS_DIR/0/open_telemetry_javaagent/opentelemetry-javaagent.jar"))
				Expect(opts).NotTo(ContainSubstring("-Dotel."))
			})
		})

		Context("with otel.service.name already set in credentials", func() {
			It("does not add a second otel.service.name from the app name", func() {
				os.Setenv("VCAP_SERVICES", `{
					"otel-collector": [{
						"name": "my-otel",
						"label": "otel-collector",
						"tags": [],
						"credentials": {
							"otel.service.name": "explicit-service-name"
						}
					}]
				}`)

				err := framework.Finalize()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(otelOptsFile())
				Expect(err).NotTo(HaveOccurred())
				opts := string(data)

				Expect(opts).To(ContainSubstring("-Dotel.service.name=explicit-service-name"))
				// Only one occurrence of otel.service.name
				Expect(countOccurrences(opts, "-Dotel.service.name=")).To(Equal(1))
			})
		})

		Context("runtime jar path uses forward slashes", func() {
			It("produces a forward-slash path suitable for the Linux container", func() {
				err := framework.Finalize()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(otelOptsFile())
				Expect(err).NotTo(HaveOccurred())

				Expect(string(data)).To(ContainSubstring("$DEPS_DIR/0/open_telemetry_javaagent/opentelemetry-javaagent.jar"))
			})
		})
	})
})

// countOccurrences counts non-overlapping occurrences of substr in s.
func countOccurrences(s, substr string) int {
	count := 0
	for i := 0; i <= len(s)-len(substr); {
		if s[i:i+len(substr)] == substr {
			count++
			i += len(substr)
		} else {
			i++
		}
	}
	return count
}
