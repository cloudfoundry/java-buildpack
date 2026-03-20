package frameworks_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("SkyWalkingAgent", func() {
	AfterEach(func() {
		os.Unsetenv("SW_AGENT_COLLECTOR_BACKEND_SERVICES")
		os.Unsetenv("SW_AGENT_NAME")
	})

	DescribeTable("configuration environment variables",
		func(envVar, expectedValue string) {
			os.Setenv(envVar, expectedValue)
			Expect(os.Getenv(envVar)).To(Equal(expectedValue))
		},
		Entry("SW_AGENT_COLLECTOR_BACKEND_SERVICES", "SW_AGENT_COLLECTOR_BACKEND_SERVICES", "skywalking-oap.example.com:11800"),
		Entry("SW_AGENT_NAME", "SW_AGENT_NAME", "my-app"),
	)
})
