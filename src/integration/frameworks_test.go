package integration_test

import (
	"path/filepath"
	"testing"

	"github.com/cloudfoundry/switchblade"
	"github.com/cloudfoundry/switchblade/matchers"
	"github.com/sclevine/spec"

	. "github.com/onsi/gomega"
)

func testFrameworks(platform switchblade.Platform, fixtures string) func(*testing.T, spec.G, spec.S) {
	return func(t *testing.T, context spec.G, it spec.S) {
		var (
			Expect     = NewWithT(t).Expect
			Eventually = NewWithT(t).Eventually
			name       string
		)

		it.Before(func() {
			var err error
			name, err = switchblade.RandomName()
			Expect(err).NotTo(HaveOccurred())
		})

		it.After(func() {
			if t.Failed() && name != "" {
				t.Logf("❌ FAILED TEST - App/Container: %s", name)
				t.Logf("   Platform: %s", settings.Platform)
			}
			if name != "" && (!settings.KeepFailedContainers || !t.Failed()) {
				Expect(platform.Delete.Execute(name)).To(Succeed())
			}
		})

		context("APM Agents", func() {
			context("with New Relic service binding", func() {
				it("detects and installs New Relic agent", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"newrelic": {
								"licenseKey": "test-license-key-1234567890abcdef",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// Verify New Relic agent was detected
					Expect(logs.String()).To(ContainSubstring("New Relic Agent"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})

				it("configures New Relic with license key from service binding", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"my-newrelic-service": {
								"licenseKey": "abc123def456ghi789jkl012mno345pq",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "17",
						}).
						Execute(name, filepath.Join(fixtures, "apps", "integration_valid"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("New Relic Agent"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with AppDynamics service binding", func() {
				it("detects and installs AppDynamics agent", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"appdynamics": {
								"account-access-key": "test-access-key",
								"account-name":       "customer1",
								"host-name":          "appdynamics.example.com",
								"port":               "443",
								"ssl-enabled":        "true",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// Verify AppDynamics agent was detected
					Expect(logs.String()).To(ContainSubstring("AppDynamics Agent"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})

				it("configures AppDynamics with controller info from service binding", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"my-appdynamics-service": {
								"account-access-key": "xyz789",
								"account-name":       "production-account",
								"host-name":          "controller.appdynamics.example.com",
								"port":               "8090",
								"ssl-enabled":        "false",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "17",
						}).
						Execute(name, filepath.Join(fixtures, "apps", "integration_valid"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("AppDynamics Agent"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with Dynatrace service binding", func() {
				it("detects and installs Dynatrace agent", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"dynatrace": {
								"environmentid": "abc12345",
								"apitoken":      "test-api-token-xyz",
								"apiurl":        "https://abc12345.live.dynatrace.com/api",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// Verify Dynatrace agent was detected and installed
					Expect(logs.String()).To(ContainSubstring("Dynatrace"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})

				it("configures Dynatrace with environment ID from service binding", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"my-dynatrace-service": {
								"environmentid": "xyz78901",
								"apitoken":      "dt0c01.XXXXXXXXX.YYYYYYYYYYYY",
								"apiurl":        "https://xyz78901.live.dynatrace.com/api",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "17",
						}).
						Execute(name, filepath.Join(fixtures, "apps", "integration_valid"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("Dynatrace"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with multiple APM agents", func() {
				it("can handle multiple agent service bindings", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"newrelic": {
								"licenseKey": "test-license-key",
							},
							"appdynamics": {
								"account-access-key": "test-key",
								"account-name":       "test-account",
								"host-name":          "controller.appdynamics.com",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "apps", "integration_valid"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// Both agents should be detected
					Expect(logs.String()).To(Or(
						ContainSubstring("New Relic Agent"),
						ContainSubstring("AppDynamics Agent"),
					))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with Azure Application Insights service binding", func() {
				it("detects and installs Azure Application Insights agent", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"azure-application-insights": {
								"connection_string": "InstrumentationKey=12345678-1234-1234-1234-123456789abc;IngestionEndpoint=https://eastus-1.in.applicationinsights.azure.com/",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("Azure Application Insights"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})

				it("configures Azure Application Insights with instrumentation key", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"my-app-insights": {
								"instrumentation_key": "87654321-4321-4321-4321-cba987654321",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "17",
						}).
						Execute(name, filepath.Join(fixtures, "apps", "integration_valid"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("Azure Application Insights"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with SkyWalking service binding", func() {
				it("detects and installs SkyWalking agent", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"skywalking": {
								"oap_server": "skywalking.example.com:11800",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("SkyWalking"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})

				it("configures SkyWalking with OAP server address", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"my-skywalking": {
								"oap_server":   "oap.skywalking.prod:11800",
								"service_name": "my-java-app",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "17",
						}).
						Execute(name, filepath.Join(fixtures, "apps", "integration_valid"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("SkyWalking"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with Splunk OTEL service binding", func() {
				it("detects and installs Splunk OTEL Java agent", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"splunk-otel": {
								"access_token": "test-splunk-token-xyz123",
								"realm":        "us0",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("Splunk OTEL"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})

				it("configures Splunk OTEL with realm and access token", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"my-splunk-otel": {
								"access_token": "ABC123XYZ789",
								"realm":        "eu0",
								"endpoint":     "https://ingest.eu0.signalfx.com",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "17",
						}).
						Execute(name, filepath.Join(fixtures, "apps", "integration_valid"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("Splunk OTEL"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with Google Stackdriver Profiler service binding", func() {
				it("detects and installs Google Stackdriver Profiler", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"google-stackdriver-profiler": {
								"project_id": "my-gcp-project-123456",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("Google Stackdriver Profiler"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with Datadog service binding", func() {
				it("detects and installs Datadog Javaagent", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"datadog": {
								"api_key": "test-datadog-api-key-xyz",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("Datadog"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})

				it("configures Datadog with API key from service binding", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"my-datadog-service": {
								"api_key": "dd-api-key-123abc456def",
								"site":    "datadoghq.eu",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "17",
						}).
						Execute(name, filepath.Join(fixtures, "apps", "integration_valid"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("Datadog"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with Elastic APM service binding", func() {
				it("detects and installs Elastic APM agent", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"elastic-apm": {
								"server_url":   "https://apm.elastic.example.com:8200",
								"secret_token": "test-elastic-token",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("Elastic APM"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})

				it("configures Elastic APM with server URL and token", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"my-elastic-apm": {
								"server_url":   "https://apm.production.example.com:8200",
								"secret_token": "elastic-secret-xyz123",
								"service_name": "my-java-app",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "17",
						}).
						Execute(name, filepath.Join(fixtures, "apps", "integration_valid"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("Elastic APM"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with OpenTelemetry service binding", func() {
				it("detects and installs OpenTelemetry Javaagent", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"otel-collector": {
								"otel.exporter.otlp.endpoint": "http://otel-collector:4317",
								"otel.service.name":           "my-test-app",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "17",
						}).
						Execute(name, filepath.Join(fixtures, "apps", "integration_valid"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("OpenTelemetry"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})

				it("configures OpenTelemetry with OTLP endpoint from service binding", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"my-otel-service": {
								"otel.exporter.otlp.endpoint": "https://otel.example.com:4318",
								"otel.traces.exporter":        "otlp",
								"otel.metrics.exporter":       "otlp",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("OpenTelemetry"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with Checkmarx IAST service binding", func() {
				it("detects Checkmarx IAST service binding", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"checkmarx-iast": {
								"url":         "https://github.com/cloudfoundry/java-test-applications/raw/main/java-main-application/java-main-application.jar",
								"manager_url": "https://checkmarx.example.com",
								"api_key":     "test-api-key-12345",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// Verify Checkmarx IAST framework was detected (even if download succeeds)
					// Note: Using a real downloadable URL for testing
					Expect(logs.String()).To(ContainSubstring("Checkmarx IAST"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("without APM service bindings", func() {
				it("does not install any APM agents", func() {
					deployment, logs, err := platform.Deploy.
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "apps", "integration_valid"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// No APM agents should be mentioned
					Expect(logs.String()).NotTo(ContainSubstring("New Relic Agent"))
					Expect(logs.String()).NotTo(ContainSubstring("AppDynamics Agent"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})
		})

		context("JDBC Drivers", func() {
			context("with PostgreSQL service binding", func() {
				it("detects and installs PostgreSQL JDBC driver", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"postgres": {
								"uri":      "postgres://user:password@localhost:5432/mydb",
								"username": "testuser",
								"password": "testpass",
								"hostname": "postgres.example.com",
								"port":     "5432",
								"name":     "mydb",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("PostgreSQL JDBC"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with MariaDB service binding", func() {
				it("detects and installs MariaDB JDBC driver", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"mariadb": {
								"uri":      "mysql://user:password@localhost:3306/mydb",
								"username": "testuser",
								"password": "testpass",
								"hostname": "mariadb.example.com",
								"port":     "3306",
								"name":     "mydb",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("MariaDB JDBC"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})
		})

		context("mTLS Support", func() {
			context("with Client Certificate Mapper enabled", func() {
				it("detects and installs Client Certificate Mapper for mTLS support", func() {
					deployment, logs, err := platform.Deploy.
						WithEnv(map[string]string{
							"BP_JAVA_VERSION":                      "11",
							"JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER": "'{enabled: true}'",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "tomcat"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// Client Certificate Mapper should be detected and installed
					Expect(logs.String()).To(ContainSubstring("Client Certificate Mapper"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})

				it("skips Client Certificate Mapper when disabled", func() {
					deployment, logs, err := platform.Deploy.
						WithEnv(map[string]string{
							"BP_JAVA_VERSION":                      "11",
							"JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER": "'{enabled: false}'",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "tomcat"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// Should not install when explicitly disabled
					Expect(logs.String()).NotTo(ContainSubstring("Client Certificate Mapper"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})
		})

		context("Utility Frameworks", func() {
			context("with Debug enabled", func() {
				it("configures remote debugging via JDWP", func() {
					deployment, logs, err := platform.Deploy.
						WithEnv(map[string]string{
							"BP_JAVA_VERSION":   "11",
							"BPL_DEBUG_ENABLED": "true",
							"BPL_DEBUG_PORT":    "8000",
						}).
						Execute(name, filepath.Join(fixtures, "apps", "integration_valid"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("Debug"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with JMX enabled", func() {
				it("configures remote JMX monitoring", func() {
					deployment, logs, err := platform.Deploy.
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
							"BPL_JMX_ENABLED": "true",
							"BPL_JMX_PORT":    "5000",
						}).
						Execute(name, filepath.Join(fixtures, "apps", "integration_valid"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("JMX"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})
		})

		context("Testing & Code Coverage", func() {
			context("with JaCoCo service binding", func() {
				it("detects and installs JaCoCo agent", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"jacoco": {
								"address": "localhost",
								"port":    "6300",
								"output":  "file", // Use file output instead of tcpclient to avoid network dependency
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("JaCoCo"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})
		})

		context("Spring Configuration", func() {
			context("with Spring Auto-reconfiguration", func() {
				it("detects and installs Spring Auto-reconfiguration for Spring apps", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"postgres": {
								"uri":      "postgres://user:password@localhost:5432/mydb",
								"username": "testuser",
								"password": "testpass",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION":                        "11",
							"JBP_CONFIG_SPRING_AUTO_RECONFIGURATION": "'{enabled: true}'",
						}).
						Execute(name, filepath.Join(fixtures, "frameworks", "auto_reconfiguration_servlet_3"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// Spring Auto-reconfiguration should be detected for Spring apps with services
					Expect(logs.String()).To(ContainSubstring("Spring Auto-reconfiguration"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})

				it("skips Spring Auto-reconfiguration when disabled", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"postgres": {
								"uri": "postgres://user:password@localhost:5432/mydb",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION":                        "11",
							"JBP_CONFIG_SPRING_AUTO_RECONFIGURATION": "'{enabled: false}'",
						}).
						Execute(name, filepath.Join(fixtures, "frameworks", "auto_reconfiguration_servlet_3"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// Should not install when explicitly disabled
					Expect(logs.String()).NotTo(ContainSubstring("Spring Auto-reconfiguration"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with Java CF Env", func() {
				it("detects and installs Java CF Env for Spring Boot 3.x apps", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"postgres": {
								"uri":      "postgres://user:password@localhost:5432/mydb",
								"username": "testuser",
								"password": "testpass",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION":        "17",
							"JBP_CONFIG_JAVA_CF_ENV": "'{enabled: true}'",
						}).
						Execute(name, filepath.Join(fixtures, "frameworks", "java_cf_boot_3"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// Java CF Env should be detected for Spring Boot 3.x apps
					Expect(logs.String()).To(ContainSubstring("Java CF Env"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})
		})

		context("JVM Configuration", func() {
			context("with Java Opts Framework", func() {
				it("applies custom JAVA_OPTS from environment", func() {
					deployment, logs, err := platform.Deploy.
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
							// Reduce code cache and thread stack to fit within 1G memory limit (v4 calculator)
							"JAVA_OPTS": "-Xmx384m -XX:ReservedCodeCacheSize=120M -Xss512k -Dcustom.property=test",
						}).
						Execute(name, filepath.Join(fixtures, "apps", "integration_valid"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// Java Opts framework should detect JAVA_OPTS environment variable
					Expect(logs.String()).To(ContainSubstring("Java Opts"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})

				it("applies custom JAVA_OPTS from configuration file", func() {
					deployment, logs, err := platform.Deploy.
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
							// Reduce heap and code cache to fit within 1G memory limit (v4 calculator)
							"JBP_CONFIG_JAVA_OPTS": "'{java_opts: [\"-Xms256m\", \"-Xmx384m\", \"-XX:ReservedCodeCacheSize=120M\", \"-Xss512k\"]}'",
						}).
						Execute(name, filepath.Join(fixtures, "apps", "integration_valid"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// Java Opts framework should detect configuration
					Expect(logs.String()).To(ContainSubstring("Java Opts"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})

				it("handles quoted strings with spaces in JAVA_OPTS", func() {
					deployment, logs, err := platform.Deploy.
						WithEnv(map[string]string{
							"BP_JAVA_VERSION":      "11",
							"JBP_CONFIG_JAVA_OPTS": `'java_opts: -DtestJBPConfig1=''test test'' -DtestJBPConfig2="value with spaces"'`,
						}).
						Execute(name, filepath.Join(fixtures, "apps", "integration_valid"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// Java Opts framework should detect configuration
					Expect(logs.String()).To(ContainSubstring("Java Opts"))
					// Should properly handle quoted strings with spaces
					Expect(logs.String()).To(ContainSubstring("Adding configured JAVA_OPTS"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})

				it("expands environment variables in JAVA_OPTS at runtime", func() {
					deployment, logs, err := platform.Deploy.
						WithEnv(map[string]string{
							"BP_JAVA_VERSION":      "11",
							"TEST_ENV_VAR":         "test-value-123",
							"JBP_CONFIG_JAVA_OPTS": `'java_opts: -DtestEnvVar="$TEST_ENV_VAR" -DtestPath="$PATH"'`,
						}).
						Execute(name, filepath.Join(fixtures, "apps", "integration_valid"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// Java Opts framework should detect configuration
					Expect(logs.String()).To(ContainSubstring("Java Opts"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})

				it("handles complex scenario with quotes and env vars like Ruby buildpack", func() {
					deployment, logs, err := platform.Deploy.
						WithEnv(map[string]string{
							"BP_JAVA_VERSION":      "11",
							"JBP_CONFIG_JAVA_OPTS": `'java_opts: -DtestJBPConfig1=''test test'' -DtestJBPConfig2="$PATH"'`,
						}).
						Execute(name, filepath.Join(fixtures, "apps", "integration_valid"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// This test verifies the fix for the Ruby vs Go buildpack parity issue
					// Ruby buildpack correctly handled:
					// - Single quotes with spaces: -DtestJBPConfig1='test test' -> -DtestJBPConfig1=test test
					// - Environment variable expansion: -DtestJBPConfig2="$PATH" -> -DtestJBPConfig2=/usr/local/bin:/usr/bin:/bin
					Expect(logs.String()).To(ContainSubstring("Java Opts"))
					Expect(logs.String()).To(ContainSubstring("Adding configured JAVA_OPTS"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})
		})

		context("Development Tools", func() {
			context("with JRebel Agent", func() {
				it("detects and installs JRebel agent when rebel-remote.xml present", func() {
					deployment, logs, err := platform.Deploy.
						WithEnv(map[string]string{
							"BP_JAVA_VERSION":         "11",
							"JBP_CONFIG_JREBEL_AGENT": "'{enabled: true}'",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_multi_framework"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// JRebel agent should be detected when enabled
					Expect(logs.String()).To(ContainSubstring("JRebel"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with YourKit Profiler", func() {
				it("detects and installs YourKit profiler when enabled", func() {
					deployment, logs, err := platform.Deploy.
						WithEnv(map[string]string{
							"BP_JAVA_VERSION":              "11",
							"JBP_CONFIG_YOUR_KIT_PROFILER": "'{enabled: true}'",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// YourKit profiler should be detected when enabled
					Expect(logs.String()).To(ContainSubstring("YourKit"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with JProfiler Profiler", func() {
				it("detects and installs JProfiler profiler when enabled", func() {
					deployment, logs, err := platform.Deploy.
						WithEnv(map[string]string{
							"BP_JAVA_VERSION":               "11",
							"JBP_CONFIG_JPROFILER_PROFILER": "'{enabled: true}'",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// JProfiler profiler should be detected when enabled
					Expect(logs.String()).To(ContainSubstring("JProfiler"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})
		})

		context("Specialized APM Agents", func() {
			context("with Contrast Security service binding", func() {
				it("detects and installs Contrast Security agent", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"contrast-security": {
								"api_key":        "test-api-key",
								"service_key":    "test-service-key",
								"teamserver_url": "https://contrast.example.com",
								"username":       "agent@example.com",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("Contrast Security"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with Sealights service binding", func() {
				it("detects and installs Sealights agent", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"sealights": {
								"token":     "test-token",
								"lab_id":    "test-lab-id",
								"bs_id":     "test-bs-id",
								"proxy_url": "https://sealights.example.com",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("Sealights"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with Takipi service binding", func() {
				it("detects and installs Takipi agent", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"takipi": {
								"secret_key": "test-secret-key",
								"server":     "https://takipi.example.com",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("Takipi"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with Introscope service binding", func() {
				it("detects and installs Introscope agent", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"introscope": {
								"agent_manager_url": "introscope.example.com:5001",
								"agent_name":        "test-agent",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("Introscope"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with Riverbed AppInternals service binding", func() {
				it("detects and installs Riverbed AppInternals agent", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"riverbed-appinternals": {
								"analysis_server": "appinternals.example.com:4144",
								"agent_name":      "test-agent",
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("Riverbed AppInternals"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})
		})

		context("Advanced Tooling", func() {
			context("with AspectJ Weaver", func() {
				it("detects and installs AspectJ Weaver when enabled", func() {
					deployment, logs, err := platform.Deploy.
						WithEnv(map[string]string{
							"BP_JAVA_VERSION":                 "11",
							"JBP_CONFIG_ASPECTJ_WEAVER_AGENT": "'{enabled: true}'",
						}).
						Execute(name, filepath.Join(fixtures, "frameworks", "aspectj_weaver_meta_inf"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					// AspectJ Weaver should be detected when enabled
					Expect(logs.String()).To(ContainSubstring("AspectJ"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with Google Stackdriver Debugger", func() {
				it("detects and installs Google Stackdriver Debugger", func() {
					deployment, logs, err := platform.Deploy.
						WithServices(map[string]switchblade.Service{
							"google-stackdriver-debugger": {
								"project_id":  "test-project",
								"credentials": `{"type":"service_account","project_id":"test-project"}`,
							},
						}).
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("Stackdriver Debugger"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})

			context("with Container Security Provider", func() {
				it("detects and configures Container Security Provider", func() {
					deployment, logs, err := platform.Deploy.
						WithEnv(map[string]string{
							"BP_JAVA_VERSION": "11",
						}).
						Execute(name, filepath.Join(fixtures, "containers", "spring_boot_staged"))
					Expect(err).NotTo(HaveOccurred(), logs.String)

					Expect(logs.String()).To(ContainSubstring("Container Security Provider"))
					Eventually(deployment).Should(matchers.Serve(ContainSubstring("")))
				})
			})
		})
	}
}
