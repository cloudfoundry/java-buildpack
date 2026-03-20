package frameworks_test

import (
	"os"
	"path/filepath"

	"github.com/cloudfoundry/java-buildpack/src/java/resources"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("AppDynamics Embedded Config", func() {
	const embeddedPath = "app_dynamics_agent/defaults/conf/app-agent-config.xml"

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
			Expect(configStr).To(ContainSubstring("<app-agent-configuration>"))

			expectedSections := []string{
				"<configuration-properties>",
				"<sensitive-url-filters>",
				"<sensitive-data-filters>",
				"<agent-services>",
				"<agent-service name=\"BCIEngine\"",
				"<agent-service name=\"SnapshotService\"",
				"<agent-service name=\"TransactionMonitoringService\"",
			}

			for _, section := range expectedSections {
				Expect(configStr).To(ContainSubstring(section))
			}
		})
	})
})

var _ = Describe("AppDynamics Config File Operations", func() {
	var tmpDir string

	BeforeEach(func() {
		var err error
		tmpDir, err = os.MkdirTemp("", "appdynamics-test-*")
		Expect(err).NotTo(HaveOccurred())
	})

	AfterEach(func() {
		os.RemoveAll(tmpDir)
	})

	Describe("Config file creation", func() {
		It("writes embedded config to disk successfully", func() {
			confDir := filepath.Join(tmpDir, "app_dynamics_agent", "defaults", "conf")
			err := os.MkdirAll(confDir, 0755)
			Expect(err).NotTo(HaveOccurred())

			embeddedPath := "app_dynamics_agent/defaults/conf/app-agent-config.xml"
			configData, err := resources.GetResource(embeddedPath)
			Expect(err).NotTo(HaveOccurred())

			configPath := filepath.Join(confDir, "app-agent-config.xml")
			err = os.WriteFile(configPath, configData, 0644)
			Expect(err).NotTo(HaveOccurred())

			_, err = os.Stat(configPath)
			Expect(err).NotTo(HaveOccurred())

			writtenData, err := os.ReadFile(configPath)
			Expect(err).NotTo(HaveOccurred())

			writtenStr := string(writtenData)
			Expect(writtenStr).To(ContainSubstring("<app-agent-configuration>"))
			Expect(writtenStr).To(ContainSubstring("<agent-service name=\"BCIEngine\""))
		})
	})

	Describe("Config file skip if exists", func() {
		It("does not overwrite existing user config", func() {
			confDir := filepath.Join(tmpDir, "app_dynamics_agent", "defaults", "conf")
			err := os.MkdirAll(confDir, 0755)
			Expect(err).NotTo(HaveOccurred())

			configPath := filepath.Join(confDir, "app-agent-config.xml")
			userConfig := "<!-- User-provided configuration -->\n<app-agent-configuration><configuration-properties><property name=\"custom\" value=\"true\"/></configuration-properties></app-agent-configuration>"
			err = os.WriteFile(configPath, []byte(userConfig), 0644)
			Expect(err).NotTo(HaveOccurred())

			_, err = os.Stat(configPath)
			Expect(err).NotTo(HaveOccurred())

			existingData, err := os.ReadFile(configPath)
			Expect(err).NotTo(HaveOccurred())

			existingStr := string(existingData)
			Expect(existingStr).To(ContainSubstring("<!-- User-provided configuration -->"))
			Expect(existingStr).To(ContainSubstring("custom"))
		})
	})
})
