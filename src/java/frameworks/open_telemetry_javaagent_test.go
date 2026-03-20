package frameworks_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("OpenTelemetryJavaagent", func() {
	AfterEach(func() {
		os.Unsetenv("OTEL_SERVICE_NAME")
		os.Unsetenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	})

	DescribeTable("configuration environment variables",
		func(envVar, expectedValue string) {
			os.Setenv(envVar, expectedValue)
			Expect(os.Getenv(envVar)).To(Equal(expectedValue))
		},
		Entry("OTEL_SERVICE_NAME", "OTEL_SERVICE_NAME", "my-service"),
		Entry("OTEL_EXPORTER_OTLP_ENDPOINT", "OTEL_EXPORTER_OTLP_ENDPOINT", "https://otel-collector.example.com"),
	)
})
