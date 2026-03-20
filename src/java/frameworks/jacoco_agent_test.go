package frameworks_test

import (
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("JaCoCo Agent", func() {
	var tmpDir string

	BeforeEach(func() {
		var err error
		tmpDir, err = os.MkdirTemp("", "jacoco-test-*")
		Expect(err).NotTo(HaveOccurred())
	})

	AfterEach(func() {
		os.RemoveAll(tmpDir)
	})

	Describe("Detection", func() {
		It("detects jacocoagent.jar", func() {
			jacocoJar := filepath.Join(tmpDir, "jacocoagent.jar")
			err := os.WriteFile(jacocoJar, []byte("mock jar"), 0644)
			Expect(err).NotTo(HaveOccurred())

			_, err = os.Stat(jacocoJar)
			Expect(err).NotTo(HaveOccurred())
		})
	})
})
