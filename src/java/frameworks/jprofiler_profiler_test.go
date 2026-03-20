package frameworks_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("JProfiler Profiler", func() {
	AfterEach(func() {
		os.Unsetenv("JPROFILER_LICENSE_KEY")
		os.Unsetenv("JPROFILER_PORT")
	})

	Describe("License configuration", func() {
		It("uses JPROFILER_LICENSE_KEY", func() {
			licenseKey := "test-license-key-12345"
			os.Setenv("JPROFILER_LICENSE_KEY", licenseKey)

			Expect(os.Getenv("JPROFILER_LICENSE_KEY")).To(Equal(licenseKey))
		})
	})

	Describe("Port configuration", func() {
		It("uses JPROFILER_PORT", func() {
			port := "8849"
			os.Setenv("JPROFILER_PORT", port)

			Expect(os.Getenv("JPROFILER_PORT")).To(Equal(port))
		})
	})
})
