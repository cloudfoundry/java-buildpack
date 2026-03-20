package frameworks_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Elastic APM Agent", func() {
	AfterEach(func() {
		os.Unsetenv("ELASTIC_APM_SERVER_URL")
		os.Unsetenv("ELASTIC_APM_SERVICE_NAME")
	})

	Describe("Service detection", func() {
		DescribeTable("detects based on environment variables",
			func(envVars map[string]string, expectDetection bool) {
				for k, v := range envVars {
					os.Setenv(k, v)
				}

				hasServerURL := os.Getenv("ELASTIC_APM_SERVER_URL") != ""
				hasServiceName := os.Getenv("ELASTIC_APM_SERVICE_NAME") != ""

				detected := hasServerURL || hasServiceName
				Expect(detected).To(Equal(expectDetection))
			},
			Entry("ELASTIC_APM_SERVER_URL set",
				map[string]string{"ELASTIC_APM_SERVER_URL": "https://apm.example.com"},
				true),
			Entry("ELASTIC_APM_SERVICE_NAME set",
				map[string]string{"ELASTIC_APM_SERVICE_NAME": "my-service"},
				true),
			Entry("no elastic env vars",
				map[string]string{},
				false),
		)
	})
})
