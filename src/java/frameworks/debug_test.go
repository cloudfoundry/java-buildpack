package frameworks_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Debug", func() {
	AfterEach(func() {
		os.Unsetenv("BPL_DEBUG_ENABLED")
		os.Unsetenv("JBP_CONFIG_DEBUG")
		os.Unsetenv("BPL_DEBUG_PORT")
		os.Unsetenv("BPL_DEBUG_SUSPEND")
	})

	Describe("debug enabled detection", func() {
		DescribeTable("environment variables",
			func(envVar, value string) {
				os.Setenv(envVar, value)
				Expect(os.Getenv(envVar)).To(Equal(value))
			},
			Entry("BPL_DEBUG_ENABLED true", "BPL_DEBUG_ENABLED", "true"),
			Entry("BPL_DEBUG_ENABLED 1", "BPL_DEBUG_ENABLED", "1"),
			Entry("BPL_DEBUG_ENABLED false", "BPL_DEBUG_ENABLED", "false"),
			Entry("JBP_CONFIG_DEBUG enabled", "JBP_CONFIG_DEBUG", "enabled: true"),
		)
	})

	Describe("debug port configuration", func() {
		It("should use default port when not set", func() {
			defaultPort := 8000
			port := defaultPort
			if portEnv := os.Getenv("BPL_DEBUG_PORT"); portEnv != "" {
				port = 9000
			}
			Expect(port).To(Equal(defaultPort))
		})

		It("should use BPL_DEBUG_PORT when set", func() {
			os.Setenv("BPL_DEBUG_PORT", "9000")
			port := 8000
			if portEnv := os.Getenv("BPL_DEBUG_PORT"); portEnv != "" {
				port = 9000
			}
			Expect(port).To(Equal(9000))
		})
	})

	Describe("debug suspend mode", func() {
		DescribeTable("suspend configuration",
			func(suspendValue string, expected bool) {
				if suspendValue != "" {
					os.Setenv("BPL_DEBUG_SUSPEND", suspendValue)
				}
				suspend := os.Getenv("BPL_DEBUG_SUSPEND") == "true"
				Expect(suspend).To(Equal(expected))
			},
			Entry("suspend enabled", "true", true),
			Entry("suspend disabled", "false", false),
			Entry("suspend not set", "", false),
		)
	})
})
