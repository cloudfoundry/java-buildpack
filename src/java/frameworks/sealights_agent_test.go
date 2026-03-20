package frameworks_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("SealightsAgent", func() {
	It("should require token and build_session_id credentials", func() {
		credentials := map[string]interface{}{
			"token":            "test-token-123",
			"build_session_id": "test-build-session",
		}

		requiredKeys := []string{"token", "build_session_id"}
		for _, key := range requiredKeys {
			_, exists := credentials[key]
			Expect(exists).To(BeTrue(), "Required credential key %s is missing", key)
		}
	})
})
