package frameworks_test

import (
	"os"
	"path/filepath"

	"github.com/cloudfoundry/java-buildpack/src/java/resources"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Azure Application Insights Agent Embedded Config", func() {
	const embeddedPath = "azure_application_insights_agent/AI-Agent.xml"

	Describe("Config file existence", func() {
		It("exists in embedded resources", func() {
			exists := resources.Exists(embeddedPath)
			Expect(exists).To(BeTrue())
		})
	})

	Describe("Config file content", func() {
		It("has expected XML structure", func() {
			configData, err := resources.GetResource(embeddedPath)
			Expect(err).NotTo(HaveOccurred())

			configStr := string(configData)
			Expect(configStr).To(ContainSubstring("<?xml version=\"1.0\" encoding=\"utf-8\"?>"))
			Expect(configStr).To(ContainSubstring("<ApplicationInsightsAgent>"))

			expectedSections := []string{
				"<Instrumentation>",
				"<BuiltIn",
				"<Jedis",
				"<MaxStatementQueryLimitInMS>",
			}

			for _, section := range expectedSections {
				Expect(configStr).To(ContainSubstring(section))
			}
		})
	})
})

var _ = Describe("Azure Application Insights Agent Config File Operations", func() {
	var tmpDir string

	BeforeEach(func() {
		var err error
		tmpDir, err = os.MkdirTemp("", "azure-test-*")
		Expect(err).NotTo(HaveOccurred())
	})

	AfterEach(func() {
		os.RemoveAll(tmpDir)
	})

	Describe("Config file creation", func() {
		It("writes embedded config to disk successfully", func() {
			agentDir := filepath.Join(tmpDir, "azure_application_insights_agent")
			err := os.MkdirAll(agentDir, 0755)
			Expect(err).NotTo(HaveOccurred())

			embeddedPath := "azure_application_insights_agent/AI-Agent.xml"
			configData, err := resources.GetResource(embeddedPath)
			Expect(err).NotTo(HaveOccurred())

			configPath := filepath.Join(agentDir, "AI-Agent.xml")
			err = os.WriteFile(configPath, configData, 0644)
			Expect(err).NotTo(HaveOccurred())

			writtenData, err := os.ReadFile(configPath)
			Expect(err).NotTo(HaveOccurred())
			Expect(string(writtenData)).To(ContainSubstring("<ApplicationInsightsAgent>"))
		})
	})

	Describe("Config file skip if exists", func() {
		It("does not overwrite existing user config", func() {
			agentDir := filepath.Join(tmpDir, "azure_application_insights_agent")
			err := os.MkdirAll(agentDir, 0755)
			Expect(err).NotTo(HaveOccurred())

			configPath := filepath.Join(agentDir, "AI-Agent.xml")
			userConfig := "<!-- User-provided configuration -->\n<ApplicationInsightsAgent><Instrumentation><BuiltIn enabled=\"false\"/></Instrumentation></ApplicationInsightsAgent>"
			err = os.WriteFile(configPath, []byte(userConfig), 0644)
			Expect(err).NotTo(HaveOccurred())

			_, err = os.Stat(configPath)
			Expect(err).NotTo(HaveOccurred())

			existingData, err := os.ReadFile(configPath)
			Expect(err).NotTo(HaveOccurred())

			existingStr := string(existingData)
			Expect(existingStr).To(ContainSubstring("<!-- User-provided configuration -->"))
			Expect(existingStr).To(ContainSubstring("enabled=\"false\""))
		})
	})
})
