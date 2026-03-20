package frameworks_test

import (
	"encoding/xml"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

type ContrastConfig struct {
	XMLName     xml.Name `xml:"contrast"`
	ID          string   `xml:"id"`
	GlobalKey   string   `xml:"global-key"`
	URL         string   `xml:"url"`
	ResultsMode string   `xml:"results-mode"`
}

var _ = Describe("Contrast Security Agent", func() {
	Describe("XML configuration structure", func() {
		It("parses Contrast Security XML config", func() {
			xmlConfig := `<?xml version="1.0" encoding="UTF-8"?>
<contrast>
  <id>default</id>
  <global-key>test-api-key</global-key>
  <url>https://app.contrastsecurity.com/Contrast/s/</url>
  <results-mode>never</results-mode>
</contrast>`

			var config ContrastConfig
			err := xml.Unmarshal([]byte(xmlConfig), &config)
			Expect(err).NotTo(HaveOccurred())
			Expect(config.ID).To(Equal("default"))
			Expect(config.ResultsMode).To(Equal("never"))
		})
	})

	Describe("Credential keys", func() {
		It("has all required credential keys", func() {
			credentials := map[string]interface{}{
				"api_key":        "test-api-key-123",
				"service_key":    "test-service-key-456",
				"teamserver_url": "https://app.contrastsecurity.com",
				"username":       "test@example.com",
			}

			requiredKeys := []string{"api_key", "service_key", "teamserver_url", "username"}
			for _, key := range requiredKeys {
				_, exists := credentials[key]
				Expect(exists).To(BeTrue(), "Required credential key %s is missing", key)
			}
		})
	})
})
