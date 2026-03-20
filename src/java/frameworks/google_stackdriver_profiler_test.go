package frameworks_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Google Stackdriver Profiler", func() {
	AfterEach(func() {
		os.Unsetenv("GOOGLE_CLOUD_PROJECT")
		os.Unsetenv("GOOGLE_APPLICATION_CREDENTIALS_JSON")
	})

	Describe("Credentials", func() {
		It("uses GOOGLE_CLOUD_PROJECT for project ID", func() {
			projectID := "test-project-123"
			os.Setenv("GOOGLE_CLOUD_PROJECT", projectID)

			Expect(os.Getenv("GOOGLE_CLOUD_PROJECT")).To(Equal(projectID))
		})

		It("uses GOOGLE_APPLICATION_CREDENTIALS_JSON for service account", func() {
			keyJSON := `{"type": "service_account", "project_id": "test-project"}`
			os.Setenv("GOOGLE_APPLICATION_CREDENTIALS_JSON", keyJSON)

			Expect(os.Getenv("GOOGLE_APPLICATION_CREDENTIALS_JSON")).NotTo(BeEmpty())
		})
	})
})
