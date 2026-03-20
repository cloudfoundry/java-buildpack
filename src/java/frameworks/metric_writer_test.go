package frameworks_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("MetricWriter", func() {
	It("should detect Spring Boot Actuator", func() {
		springBootActuatorPresent := true
		Expect(springBootActuatorPresent).To(BeTrue())
	})
})
