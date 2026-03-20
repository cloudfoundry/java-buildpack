package frameworks_test

import (
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("ContainerCustomizer", func() {
	var tmpDir string

	BeforeEach(func() {
		var err error
		tmpDir, err = os.MkdirTemp("", "container-customizer-test-*")
		Expect(err).NotTo(HaveOccurred())
	})

	AfterEach(func() {
		os.RemoveAll(tmpDir)
	})

	It("should detect Spring Boot WAR", func() {
		webInfDir := filepath.Join(tmpDir, "WEB-INF")
		bootInfDir := filepath.Join(tmpDir, "BOOT-INF")
		webInfLib := filepath.Join(webInfDir, "lib")
		bootInfLib := filepath.Join(bootInfDir, "lib")

		err := os.MkdirAll(webInfLib, 0755)
		Expect(err).NotTo(HaveOccurred())
		err = os.MkdirAll(bootInfLib, 0755)
		Expect(err).NotTo(HaveOccurred())

		springBootJar := filepath.Join(webInfLib, "spring-boot-2.7.0.jar")
		err = os.WriteFile(springBootJar, []byte("mock jar"), 0644)
		Expect(err).NotTo(HaveOccurred())

		Expect(webInfDir).To(BeADirectory())
		Expect(bootInfDir).To(BeADirectory())
		Expect(springBootJar).To(BeARegularFile())
	})

	It("should check multiple lib locations", func() {
		locations := []string{
			filepath.Join(tmpDir, "WEB-INF", "lib"),
			filepath.Join(tmpDir, "BOOT-INF", "lib"),
		}

		for _, loc := range locations {
			err := os.MkdirAll(loc, 0755)
			Expect(err).NotTo(HaveOccurred())
		}

		springBootJar := filepath.Join(locations[0], "spring-boot-starter-web-2.7.0.jar")
		err := os.WriteFile(springBootJar, []byte("mock jar"), 0644)
		Expect(err).NotTo(HaveOccurred())

		Expect(springBootJar).To(BeARegularFile())
	})

	It("should ignore non-Spring Boot WAR", func() {
		webInfLib := filepath.Join(tmpDir, "WEB-INF", "lib")
		err := os.MkdirAll(webInfLib, 0755)
		Expect(err).NotTo(HaveOccurred())

		otherJar := filepath.Join(webInfLib, "servlet-api-3.1.0.jar")
		err = os.WriteFile(otherJar, []byte("mock jar"), 0644)
		Expect(err).NotTo(HaveOccurred())

		Expect(webInfLib).To(BeADirectory())
	})
})
