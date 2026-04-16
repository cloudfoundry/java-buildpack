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

var _ = Describe("SplunkOtelJavaAgent", func() {
	var (
		ctx       *common.Context
		framework *frameworks.SplunkOtelJavaAgentFramework
		tmpDir    string
		depsDir   string
		agentDir  string
	)

	BeforeEach(func() {
		var err error
		tmpDir, err = os.MkdirTemp("", "splunk-otel-test-*")
		Expect(err).NotTo(HaveOccurred())

		depsDir = filepath.Join(tmpDir, "deps")
		err = os.MkdirAll(filepath.Join(depsDir, "0"), 0755)
		Expect(err).NotTo(HaveOccurred())

		agentDir = filepath.Join(depsDir, "0", "splunk_otel_java_agent")

		logger := libbuildpack.NewLogger(os.Stdout)
		manifest := &libbuildpack.Manifest{}
		stager := libbuildpack.NewStager([]string{tmpDir, "", depsDir, "0"}, logger, manifest)

		ctx = &common.Context{
			Stager:   stager,
			Manifest: manifest,
			Log:      logger,
		}

		framework = frameworks.NewSplunkOtelJavaAgentFramework(ctx)
	})

	AfterEach(func() {
		os.RemoveAll(tmpDir)
		os.Unsetenv("VCAP_SERVICES")
		os.Unsetenv("SPLUNK_OTEL_AGENT")
		os.Unsetenv("OTEL_EXPORTER_OTLP_ENDPOINT")
		os.Unsetenv("SPLUNK_ACCESS_TOKEN")
		os.Unsetenv("SPLUNK_REALM")
	})

	Describe("Detect", func() {
		Context("without any binding or environment variable", func() {
			It("does not detect", func() {
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with SPLUNK_OTEL_AGENT environment variable", func() {
			It("detects successfully", func() {
				os.Setenv("SPLUNK_OTEL_AGENT", "/path/to/agent.jar")
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Splunk OTEL"))
			})
		})

		Context("with OTEL_EXPORTER_OTLP_ENDPOINT environment variable", func() {
			It("detects successfully", func() {
				os.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://collector:4318")
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Splunk OTEL"))
			})
		})

		Context("with splunk service label", func() {
			It("detects successfully", func() {
				os.Setenv("VCAP_SERVICES", `{
					"splunk": [{
						"name": "my-splunk",
						"label": "splunk",
						"tags": [],
						"credentials": {}
					}]
				}`)
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Splunk OTEL"))
			})
		})

		Context("with splunk-otel service label", func() {
			It("detects successfully", func() {
				os.Setenv("VCAP_SERVICES", `{
					"splunk-otel": [{
						"name": "my-splunk-otel",
						"label": "splunk-otel",
						"tags": [],
						"credentials": {}
					}]
				}`)
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Splunk OTEL"))
			})
		})

		Context("with splunk tag", func() {
			It("detects via tag", func() {
				os.Setenv("VCAP_SERVICES", `{
					"user-provided": [{
						"name": "my-apm",
						"label": "user-provided",
						"tags": ["splunk"],
						"credentials": {}
					}]
				}`)
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Splunk OTEL"))
			})
		})

		Context("with user-provided service matching splunk name pattern", func() {
			It("detects via name pattern", func() {
				os.Setenv("VCAP_SERVICES", `{
					"user-provided": [{
						"name": "my-splunk-collector",
						"label": "user-provided",
						"tags": [],
						"credentials": {}
					}]
				}`)
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Splunk OTEL"))
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
		splunkOptsFile := func() string {
			return filepath.Join(depsDir, "0", "java_opts", "42_splunk_otel_java_agent.opts")
		}

		createJar := func(name string) {
			err := os.MkdirAll(agentDir, 0755)
			Expect(err).NotTo(HaveOccurred())
			err = os.WriteFile(filepath.Join(agentDir, name), []byte("fake jar"), 0644)
			Expect(err).NotTo(HaveOccurred())
		}

		Context("with primary jar name", func() {
			BeforeEach(func() { createJar("splunk-otel-javaagent.jar") })

			It("writes javaagent flag to opts file", func() {
				err := framework.Finalize()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(splunkOptsFile())
				Expect(err).NotTo(HaveOccurred())
				Expect(string(data)).To(ContainSubstring("-javaagent:$DEPS_DIR/0/splunk_otel_java_agent/splunk-otel-javaagent.jar"))
			})

			It("uses forward slashes in the runtime jar path", func() {
				err := framework.Finalize()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(splunkOptsFile())
				Expect(err).NotTo(HaveOccurred())
				Expect(string(data)).NotTo(ContainSubstring(`\`))
			})
		})

		Context("with alternative jar name (splunk-otel-javaagent-all.jar)", func() {
			BeforeEach(func() { createJar("splunk-otel-javaagent-all.jar") })

			It("falls back to the -all jar and writes javaagent flag", func() {
				err := framework.Finalize()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(splunkOptsFile())
				Expect(err).NotTo(HaveOccurred())
				Expect(string(data)).To(ContainSubstring("-javaagent:$DEPS_DIR/0/splunk_otel_java_agent/splunk-otel-javaagent-all.jar"))
			})
		})

		Context("when jar is missing", func() {
			It("returns an error", func() {
				err := framework.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("splunk OTEL Java agent JAR path not found"))
			})
		})

		Context("with credentials from environment variables", func() {
			BeforeEach(func() { createJar("splunk-otel-javaagent.jar") })

			It("writes OTLP endpoint from env", func() {
				os.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://collector:4318")

				err := framework.Finalize()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(splunkOptsFile())
				Expect(err).NotTo(HaveOccurred())
				Expect(string(data)).To(ContainSubstring("-Dotel.exporter.otlp.endpoint=http://collector:4318"))
			})

			It("writes access token from env", func() {
				os.Setenv("SPLUNK_ACCESS_TOKEN", "my-token")

				err := framework.Finalize()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(splunkOptsFile())
				Expect(err).NotTo(HaveOccurred())
				Expect(string(data)).To(ContainSubstring("-Dsplunk.access.token=my-token"))
			})

			It("writes realm from env", func() {
				os.Setenv("SPLUNK_REALM", "us1")

				err := framework.Finalize()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(splunkOptsFile())
				Expect(err).NotTo(HaveOccurred())
				Expect(string(data)).To(ContainSubstring("-Dsplunk.realm=us1"))
			})

			It("env OTLP endpoint takes precedence over service binding", func() {
				os.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://env-collector:4318")
				os.Setenv("VCAP_SERVICES", `{
					"splunk": [{
						"name": "my-splunk",
						"label": "splunk",
						"tags": [],
						"credentials": {"otlp_endpoint": "http://binding-collector:4318"}
					}]
				}`)

				err := framework.Finalize()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(splunkOptsFile())
				Expect(err).NotTo(HaveOccurred())
				opts := string(data)
				Expect(opts).To(ContainSubstring("http://env-collector:4318"))
				Expect(opts).NotTo(ContainSubstring("http://binding-collector:4318"))
			})
		})

		Context("with credentials from splunk service binding", func() {
			BeforeEach(func() { createJar("splunk-otel-javaagent.jar") })

			DescribeTable("credential key variants for OTLP endpoint",
				func(credKey string) {
					os.Setenv("VCAP_SERVICES", `{
						"splunk": [{
							"name": "my-splunk",
							"label": "splunk",
							"tags": [],
							"credentials": {"`+credKey+`": "http://collector:4318"}
						}]
					}`)

					err := framework.Finalize()
					Expect(err).NotTo(HaveOccurred())

					data, err := os.ReadFile(splunkOptsFile())
					Expect(err).NotTo(HaveOccurred())
					Expect(string(data)).To(ContainSubstring("-Dotel.exporter.otlp.endpoint=http://collector:4318"))
				},
				Entry("otlp_endpoint", "otlp_endpoint"),
				Entry("otlpEndpoint", "otlpEndpoint"),
				Entry("endpoint", "endpoint"),
			)

			DescribeTable("credential key variants for access token",
				func(credKey string) {
					os.Setenv("VCAP_SERVICES", `{
						"splunk": [{
							"name": "my-splunk",
							"label": "splunk",
							"tags": [],
							"credentials": {"`+credKey+`": "tok-abc123"}
						}]
					}`)

					err := framework.Finalize()
					Expect(err).NotTo(HaveOccurred())

					data, err := os.ReadFile(splunkOptsFile())
					Expect(err).NotTo(HaveOccurred())
					Expect(string(data)).To(ContainSubstring("-Dsplunk.access.token=tok-abc123"))
				},
				Entry("access_token", "access_token"),
				Entry("accessToken", "accessToken"),
				Entry("token", "token"),
			)

			It("reads realm from service binding", func() {
				os.Setenv("VCAP_SERVICES", `{
					"splunk": [{
						"name": "my-splunk",
						"label": "splunk",
						"tags": [],
						"credentials": {"realm": "eu0"}
					}]
				}`)

				err := framework.Finalize()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(splunkOptsFile())
				Expect(err).NotTo(HaveOccurred())
				Expect(string(data)).To(ContainSubstring("-Dsplunk.realm=eu0"))
			})

			It("prefers splunk label over splunk-otel label", func() {
				os.Setenv("VCAP_SERVICES", `{
					"splunk": [{
						"name": "explicit-splunk",
						"label": "splunk",
						"tags": [],
						"credentials": {"otlp_endpoint": "http://splunk-endpoint:4318"}
					}],
					"splunk-otel": [{
						"name": "splunk-otel-svc",
						"label": "splunk-otel",
						"tags": [],
						"credentials": {"otlp_endpoint": "http://splunk-otel-endpoint:4318"}
					}]
				}`)

				err := framework.Finalize()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(splunkOptsFile())
				Expect(err).NotTo(HaveOccurred())
				Expect(string(data)).To(ContainSubstring("http://splunk-endpoint:4318"))
				Expect(string(data)).NotTo(ContainSubstring("http://splunk-otel-endpoint:4318"))
			})

			It("falls back to name pattern when no explicit label matches", func() {
				os.Setenv("VCAP_SERVICES", `{
					"user-provided": [{
						"name": "my-splunk-collector",
						"label": "user-provided",
						"tags": [],
						"credentials": {"otlp_endpoint": "http://pattern-endpoint:4318"}
					}]
				}`)

				err := framework.Finalize()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(splunkOptsFile())
				Expect(err).NotTo(HaveOccurred())
				Expect(string(data)).To(ContainSubstring("http://pattern-endpoint:4318"))
			})

			It("does not pick up an unrelated user-provided service", func() {
				os.Setenv("VCAP_SERVICES", `{
					"user-provided": [{
						"name": "my-database",
						"label": "user-provided",
						"tags": [],
						"credentials": {"otlp_endpoint": "http://db-endpoint:4318"}
					}]
				}`)

				err := framework.Finalize()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(splunkOptsFile())
				Expect(err).NotTo(HaveOccurred())
				Expect(string(data)).NotTo(ContainSubstring("http://db-endpoint:4318"))
			})
		})

		Context("without any credentials", func() {
			BeforeEach(func() { createJar("splunk-otel-javaagent.jar") })

			It("writes only the javaagent flag", func() {
				err := framework.Finalize()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(splunkOptsFile())
				Expect(err).NotTo(HaveOccurred())
				opts := string(data)

				Expect(opts).To(ContainSubstring("-javaagent:"))
				Expect(opts).NotTo(ContainSubstring("-Dotel.exporter.otlp.endpoint="))
				Expect(opts).NotTo(ContainSubstring("-Dsplunk.access.token="))
				Expect(opts).NotTo(ContainSubstring("-Dsplunk.realm="))
			})
		})
	})
})
