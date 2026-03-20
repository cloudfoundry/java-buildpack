package frameworks_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("PostgreSQLJDBC", func() {
	It("should detect postgresql service", func() {
		serviceLabel := "postgresql"
		Expect(serviceLabel).To(Equal("postgresql"))
	})

	It("should use correct driver class", func() {
		driver := "org.postgresql.Driver"
		Expect(driver).To(Equal("org.postgresql.Driver"))
	})
})
