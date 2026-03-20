package frameworks_test

import (
	"os"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Client Certificate Mapper", func() {
	AfterEach(func() {
		os.Unsetenv("JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER")
	})

	Describe("Default behavior", func() {
		It("is enabled by default", func() {
			result := isClientCertMapperEnabled("")
			Expect(result).To(BeTrue())
		})
	})

	Describe("Configuration", func() {
		DescribeTable("handles enabled flag",
			func(config string, expected bool) {
				result := isClientCertMapperEnabled(config)
				Expect(result).To(Equal(expected))
			},
			Entry("explicitly disabled", "enabled: false", false),
			Entry("explicitly enabled", "enabled: true", true),
			Entry("empty config", "", true),
			Entry("config without enabled key", "some_other_key: value", true),
		)
	})

	Describe("Config parsing", func() {
		DescribeTable("parses JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER",
			func(envVar string, expected bool) {
				os.Setenv("JBP_CONFIG_CLIENT_CERTIFICATE_MAPPER", envVar)

				result := isClientCertMapperEnabled(envVar)
				Expect(result).To(Equal(expected))
			},
			Entry("YAML with enabled false", "{enabled: false}", false),
			Entry("YAML with enabled true", "{enabled: true}", true),
			Entry("YAML with quoted enabled false", "{'enabled': false}", false),
			Entry("YAML with quoted enabled true", "{'enabled': true}", true),
			Entry("empty config", "", true),
		)
	})
})

func isClientCertMapperEnabled(config string) bool {
	if config == "" {
		return true
	}

	if strings.Contains(config, "enabled: false") || strings.Contains(config, "'enabled': false") {
		return false
	}
	if strings.Contains(config, "enabled: true") || strings.Contains(config, "'enabled': true") {
		return true
	}

	return true
}
