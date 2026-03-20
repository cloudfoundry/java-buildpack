package frameworks_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Java Opts Writer", func() {
	AfterEach(func() {
		os.Unsetenv("JAVA_OPTS")
	})

	Describe("Basic options", func() {
		It("writes JAVA_OPTS correctly", func() {
			javaOpts := "-Xmx512M -Xms256M"
			os.Setenv("JAVA_OPTS", javaOpts)

			Expect(os.Getenv("JAVA_OPTS")).To(Equal(javaOpts))
		})
	})
})
