package frameworks_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("SplunkOtelJavaAgent", func() {
	AfterEach(func() {
		os.Unsetenv("SPLUNK_ACCESS_TOKEN")
		os.Unsetenv("SPLUNK_REALM")
	})

	DescribeTable("configuration environment variables",
		func(envVar, expectedValue string) {
			os.Setenv(envVar, expectedValue)
			Expect(os.Getenv(envVar)).To(Equal(expectedValue))
		},
		Entry("SPLUNK_ACCESS_TOKEN", "SPLUNK_ACCESS_TOKEN", "test-token-abc123"),
		Entry("SPLUNK_REALM", "SPLUNK_REALM", "us0"),
	)
})
