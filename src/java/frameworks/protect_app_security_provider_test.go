package frameworks_test

import (
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/java-buildpack/src/java/resources"
)

var _ = Describe("ProtectAppSecurityProvider", func() {
	var embeddedPath string

	BeforeEach(func() {
		embeddedPath = "protect_app_security_provider/IngrianNAE.properties"
	})

	It("should have embedded config file", func() {
		exists := resources.Exists(embeddedPath)
		Expect(exists).To(BeTrue(), "Expected embedded resource '%s' to exist", embeddedPath)
	})

	It("should have expected properties", func() {
		configData, err := resources.GetResource(embeddedPath)
		Expect(err).NotTo(HaveOccurred())

		configStr := string(configData)
		expectedProperties := []string{
			"Version=",
			"NAE_IP.1=",
			"NAE_Port=",
			"Protocol=ssl",
			"Connection_Pool",
			"Connection_Timeout",
			"Key_Store_Location=",
			"FIPS_Mode=",
			"Log_Level=",
		}

		for _, prop := range expectedProperties {
			Expect(configStr).To(ContainSubstring(prop), "Expected property '%s' in IngrianNAE.properties", prop)
		}
	})

	Context("config file creation", func() {
		var tmpDir string
		var protectAppDir string

		BeforeEach(func() {
			var err error
			tmpDir, err = os.MkdirTemp("", "protectapp-test-*")
			Expect(err).NotTo(HaveOccurred())
			protectAppDir = filepath.Join(tmpDir, "protect_app_security_provider")
		})

		AfterEach(func() {
			os.RemoveAll(tmpDir)
		})

		It("should create config file from embedded resource", func() {
			err := os.MkdirAll(protectAppDir, 0755)
			Expect(err).NotTo(HaveOccurred())

			configData, err := resources.GetResource(embeddedPath)
			Expect(err).NotTo(HaveOccurred())

			configPath := filepath.Join(protectAppDir, "IngrianNAE.properties")
			err = os.WriteFile(configPath, configData, 0644)
			Expect(err).NotTo(HaveOccurred())

			writtenData, err := os.ReadFile(configPath)
			Expect(err).NotTo(HaveOccurred())
			Expect(string(writtenData)).To(ContainSubstring("Version="))
			Expect(string(writtenData)).To(ContainSubstring("NAE_Port="))
		})

		It("should not overwrite existing config", func() {
			err := os.MkdirAll(protectAppDir, 0755)
			Expect(err).NotTo(HaveOccurred())

			configPath := filepath.Join(protectAppDir, "IngrianNAE.properties")
			userConfig := "# User-provided ProtectApp configuration\nVersion=3.0\nNAE_IP.1=192.168.1.100\nCustomProperty=CustomValue\n"
			err = os.WriteFile(configPath, []byte(userConfig), 0644)
			Expect(err).NotTo(HaveOccurred())

			_, err = os.Stat(configPath)
			Expect(err).NotTo(HaveOccurred(), "Should have detected existing config file")

			existingData, err := os.ReadFile(configPath)
			Expect(err).NotTo(HaveOccurred())

			existingStr := string(existingData)
			Expect(existingStr).To(ContainSubstring("# User-provided ProtectApp configuration"))
			Expect(existingStr).To(ContainSubstring("CustomProperty=CustomValue"))
			Expect(existingStr).To(ContainSubstring("192.168.1.100"))
		})
	})
})
