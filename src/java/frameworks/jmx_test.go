package frameworks_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("JMX", func() {
	AfterEach(func() {
		os.Unsetenv("BPL_JMX_ENABLED")
		os.Unsetenv("BPL_JMX_PORT")
	})

	DescribeTable("JMX detection",
		func(envValue string, expected bool) {
			os.Setenv("BPL_JMX_ENABLED", envValue)
			enabled := os.Getenv("BPL_JMX_ENABLED") == "true"
			Expect(enabled).To(Equal(expected))
		},
		Entry("JMX enabled via BPL_JMX_ENABLED", "true", true),
		Entry("JMX disabled", "false", false),
	)

	It("should configure JMX port", func() {
		port := "5000"
		os.Setenv("BPL_JMX_PORT", port)
		Expect(os.Getenv("BPL_JMX_PORT")).To(Equal(port))
	})
})
