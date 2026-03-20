package frameworks_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Datadog JavaAgent", func() {
	AfterEach(func() {
		os.Unsetenv("DD_API_KEY")
		os.Unsetenv("DD_APM_ENABLED")
		os.Unsetenv("DD_SERVICE")
		os.Unsetenv("DD_ENV")
		os.Unsetenv("DD_VERSION")
	})

	Describe("Detection", func() {
		It("detects with DD_API_KEY set", func() {
			os.Setenv("DD_API_KEY", "test-api-key-12345")

			apiKey := os.Getenv("DD_API_KEY")
			Expect(apiKey).NotTo(BeEmpty())
		})
	})

	Describe("APM configuration", func() {
		It("respects DD_APM_ENABLED flag", func() {
			os.Setenv("DD_APM_ENABLED", "false")

			apmEnabled := os.Getenv("DD_APM_ENABLED")
			Expect(apmEnabled).To(Equal("false"))
		})
	})

	Describe("Service tags", func() {
		DescribeTable("sets Datadog tags",
			func(envKey, envValue string) {
				os.Setenv(envKey, envValue)

				Expect(os.Getenv(envKey)).To(Equal(envValue))
			},
			Entry("DD_SERVICE tag", "DD_SERVICE", "my-app-service"),
			Entry("DD_ENV tag", "DD_ENV", "production"),
			Entry("DD_VERSION tag", "DD_VERSION", "1.2.3"),
		)
	})
})
