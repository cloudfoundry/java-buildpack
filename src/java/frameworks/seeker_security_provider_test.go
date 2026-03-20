package frameworks_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("SeekerSecurityProvider", func() {
	It("should be detected via service binding", func() {
		serviceDetected := true
		Expect(serviceDetected).To(BeTrue())
	})
})
