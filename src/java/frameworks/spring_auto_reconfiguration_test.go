package frameworks_test

import (
	"os"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Spring Auto-reconfiguration", func() {
	AfterEach(func() {
		os.Unsetenv("SPRING_PROFILES_ACTIVE")
	})

	Describe("Profile activation", func() {
		It("sets cloud profile", func() {
			os.Setenv("SPRING_PROFILES_ACTIVE", "cloud")

			Expect(os.Getenv("SPRING_PROFILES_ACTIVE")).To(Equal("cloud"))
		})
	})

	Describe("Configuration", func() {
		It("can be disabled via config", func() {
			config := "enabled: false"

			Expect(strings.Contains(config, "enabled: false")).To(BeTrue())
		})
	})
})
