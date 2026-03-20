package frameworks_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Introscope Agent", func() {
	Describe("Configuration", func() {
		It("validates required credentials", func() {
			credentials := map[string]interface{}{
				"agent_manager_url": "introscope-em.example.com",
				"agent_name":        "MyApp",
			}

			url, ok := credentials["agent_manager_url"].(string)
			Expect(ok).To(BeTrue())
			Expect(url).NotTo(BeEmpty(), "agent_manager_url is required for Introscope")

			name, ok := credentials["agent_name"].(string)
			Expect(ok).To(BeTrue())
			Expect(name).NotTo(BeEmpty(), "agent_name is required for Introscope")
		})
	})
})
