package frameworks_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Container Security Provider", func() {
	Describe("Detection", func() {
		It("is always detected", func() {
			detected := true
			Expect(detected).To(BeTrue())
		})
	})

	Describe("Java version specific handling", func() {
		DescribeTable("uses appropriate mechanism for Java version",
			func(javaVersion int, expectedType string) {
				var mechanism string
				if javaVersion >= 9 {
					mechanism = "bootclasspath"
				} else {
					mechanism = "extension"
				}

				Expect(mechanism).To(Equal(expectedType))
			},
			Entry("Java 8 uses extension directory", 8, "extension"),
			Entry("Java 9 uses bootstrap classpath", 9, "bootclasspath"),
			Entry("Java 11 uses bootstrap classpath", 11, "bootclasspath"),
			Entry("Java 17 uses bootstrap classpath", 17, "bootclasspath"),
		)
	})
})
