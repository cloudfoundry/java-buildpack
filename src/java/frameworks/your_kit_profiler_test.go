package frameworks_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("YourKitProfiler", func() {
	AfterEach(func() {
		os.Unsetenv("YOURKIT_LICENSE_KEY")
		os.Unsetenv("YOURKIT_PORT")
	})

	It("should read license key from environment", func() {
		licenseKey := "test-yourkit-license-key"
		os.Setenv("YOURKIT_LICENSE_KEY", licenseKey)
		Expect(os.Getenv("YOURKIT_LICENSE_KEY")).To(Equal(licenseKey))
	})

	It("should read port from environment", func() {
		port := "10001"
		os.Setenv("YOURKIT_PORT", port)
		Expect(os.Getenv("YOURKIT_PORT")).To(Equal(port))
	})
})
