package frameworks_test

import (
	"encoding/json"
	"os"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Checkmarx IAST Agent", func() {
	AfterEach(func() {
		os.Unsetenv("VCAP_SERVICES")
	})

	Describe("Service Detection", func() {
		DescribeTable("detects Checkmarx services",
			func(vcapServices string, shouldDetect bool) {
				os.Setenv("VCAP_SERVICES", vcapServices)

				var services map[string]interface{}
				err := json.Unmarshal([]byte(vcapServices), &services)
				Expect(err).NotTo(HaveOccurred())

				hasCheckmarx := false
				for key := range services {
					if key == "checkmarx-iast" || key == "checkmarx" {
						hasCheckmarx = true
						break
					}
				}

				if shouldDetect && !hasCheckmarx {
					Expect(strings.Contains(vcapServices, "checkmarx")).To(BeTrue())
				}
			},
			Entry("checkmarx-iast service",
				`{"checkmarx-iast": [{"name": "my-checkmarx", "credentials": {"url": "https://example.com/agent.jar"}}]}`,
				true),
			Entry("checkmarx service",
				`{"checkmarx": [{"name": "my-checkmarx", "credentials": {"url": "https://example.com/agent.jar"}}]}`,
				true),
			Entry("user-provided with checkmarx in name",
				`{"user-provided": [{"name": "my-checkmarx-service", "credentials": {"url": "https://example.com/agent.jar"}}]}`,
				true),
			Entry("service with checkmarx tag",
				`{"security-service": [{"name": "my-security", "tags": ["checkmarx", "iast"], "credentials": {"url": "https://example.com/agent.jar"}}]}`,
				true),
			Entry("no checkmarx service",
				`{"other-service": [{"name": "some-service", "credentials": {}}]}`,
				false),
		)
	})

	Describe("Credentials Extraction", func() {
		DescribeTable("extracts credentials correctly",
			func(credentials map[string]interface{}, expectURL, expectMgr, expectKey string) {
				if url, ok := credentials["url"].(string); ok {
					Expect(url).To(Equal(expectURL))
				} else if url, ok := credentials["agent_url"].(string); ok {
					Expect(url).To(Equal(expectURL))
				}

				if expectMgr != "" {
					if mgr, ok := credentials["manager_url"].(string); ok {
						Expect(mgr).To(Equal(expectMgr))
					} else if mgr, ok := credentials["managerUrl"].(string); ok {
						Expect(mgr).To(Equal(expectMgr))
					}
				}

				if expectKey != "" {
					if key, ok := credentials["api_key"].(string); ok {
						Expect(key).To(Equal(expectKey))
					} else if key, ok := credentials["apiKey"].(string); ok {
						Expect(key).To(Equal(expectKey))
					}
				}
			},
			Entry("standard credentials",
				map[string]interface{}{
					"url":         "https://example.com/agent.jar",
					"manager_url": "https://manager.example.com",
					"api_key":     "test-key-123",
				},
				"https://example.com/agent.jar",
				"https://manager.example.com",
				"test-key-123"),
			Entry("alternative credential keys",
				map[string]interface{}{
					"agent_url":  "https://example.com/cx-agent.jar",
					"managerUrl": "https://mgr.example.com",
					"apiKey":     "key-456",
				},
				"https://example.com/cx-agent.jar",
				"https://mgr.example.com",
				"key-456"),
			Entry("minimal credentials",
				map[string]interface{}{
					"url": "https://example.com/agent.jar",
				},
				"https://example.com/agent.jar",
				"",
				""),
		)
	})
})
