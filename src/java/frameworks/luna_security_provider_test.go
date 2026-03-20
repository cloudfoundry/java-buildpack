package frameworks_test

import (
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/java-buildpack/src/java/resources"
)

var _ = Describe("LunaSecurityProvider", func() {
	var embeddedPath string

	BeforeEach(func() {
		embeddedPath = "luna_security_provider/Chrystoki.conf"
	})

	It("should have embedded config file", func() {
		exists := resources.Exists(embeddedPath)
		Expect(exists).To(BeTrue(), "Expected embedded resource '%s' to exist", embeddedPath)
	})

	It("should have expected configuration structure", func() {
		configData, err := resources.GetResource(embeddedPath)
		Expect(err).NotTo(HaveOccurred())

		configStr := string(configData)
		expectedSections := []string{
			"Luna = {",
			"CloningCommandTimeOut",
			"DefaultTimeOut",
			"KeypairGenTimeOut",
			"Misc = {",
			"PE1746Enabled",
		}

		for _, section := range expectedSections {
			Expect(configStr).To(ContainSubstring(section), "Expected configuration section '%s' in Chrystoki.conf", section)
		}
	})

	Context("config file creation", func() {
		var tmpDir string
		var lunaDir string

		BeforeEach(func() {
			var err error
			tmpDir, err = os.MkdirTemp("", "luna-test-*")
			Expect(err).NotTo(HaveOccurred())
			lunaDir = filepath.Join(tmpDir, "luna_security_provider")
		})

		AfterEach(func() {
			os.RemoveAll(tmpDir)
		})

		It("should create config file from embedded resource", func() {
			err := os.MkdirAll(lunaDir, 0755)
			Expect(err).NotTo(HaveOccurred())

			configData, err := resources.GetResource(embeddedPath)
			Expect(err).NotTo(HaveOccurred())

			configPath := filepath.Join(lunaDir, "Chrystoki.conf")
			err = os.WriteFile(configPath, configData, 0644)
			Expect(err).NotTo(HaveOccurred())

			writtenData, err := os.ReadFile(configPath)
			Expect(err).NotTo(HaveOccurred())
			Expect(string(writtenData)).To(ContainSubstring("Luna = {"))
			Expect(string(writtenData)).To(ContainSubstring("DefaultTimeOut"))
		})

		It("should not overwrite existing config", func() {
			err := os.MkdirAll(lunaDir, 0755)
			Expect(err).NotTo(HaveOccurred())

			configPath := filepath.Join(lunaDir, "Chrystoki.conf")
			userConfig := "# User-provided Luna configuration\nLuna = {\n  CustomTimeout = 999999;\n}\n"
			err = os.WriteFile(configPath, []byte(userConfig), 0644)
			Expect(err).NotTo(HaveOccurred())

			_, err = os.Stat(configPath)
			Expect(err).NotTo(HaveOccurred(), "Should have detected existing config file")

			existingData, err := os.ReadFile(configPath)
			Expect(err).NotTo(HaveOccurred())

			existingStr := string(existingData)
			Expect(existingStr).To(ContainSubstring("# User-provided Luna configuration"))
			Expect(existingStr).To(ContainSubstring("CustomTimeout = 999999"))
		})
	})
})
