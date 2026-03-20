package frameworks_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("RiverbedAppInternalsAgent", func() {
	It("should require analysis_server credential", func() {
		credentials := map[string]interface{}{
			"analysis_server": "riverbed.example.com",
		}

		server, ok := credentials["analysis_server"].(string)
		Expect(ok).To(BeTrue())
		Expect(server).NotTo(BeEmpty())
	})
})
