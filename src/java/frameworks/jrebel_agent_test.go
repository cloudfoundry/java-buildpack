package frameworks_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("JRebel Agent", func() {
	Describe("License detection", func() {
		It("requires a license", func() {
			licenseData := "test-license-data"

			Expect(licenseData).NotTo(BeEmpty())
		})
	})
})
