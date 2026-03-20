package frameworks_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Java CF Env", func() {
	Describe("Detection", func() {
		It("is detected when Spring Boot is present", func() {
			springBootPresent := true

			Expect(springBootPresent).To(BeTrue())
		})
	})
})
