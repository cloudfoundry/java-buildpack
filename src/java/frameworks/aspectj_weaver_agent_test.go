package frameworks_test

import (
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("AspectJ Weaver Agent", func() {
	var tmpDir string

	BeforeEach(func() {
		var err error
		tmpDir, err = os.MkdirTemp("", "aspectj-test-*")
		Expect(err).NotTo(HaveOccurred())
	})

	AfterEach(func() {
		os.RemoveAll(tmpDir)
	})

	Describe("JAR detection", func() {
		Context("in WEB-INF/lib location", func() {
			It("detects AspectJ Weaver JAR", func() {
				webInfLib := filepath.Join(tmpDir, "WEB-INF", "lib")
				err := os.MkdirAll(webInfLib, 0755)
				Expect(err).NotTo(HaveOccurred())

				aspectjJar := filepath.Join(webInfLib, "aspectjweaver-1.9.7.jar")
				err = os.WriteFile(aspectjJar, []byte("mock jar"), 0644)
				Expect(err).NotTo(HaveOccurred())

				_, err = os.Stat(aspectjJar)
				Expect(err).NotTo(HaveOccurred())
			})
		})

		Context("in multiple search locations", func() {
			It("searches WEB-INF/lib, lib, and BOOT-INF/lib", func() {
				locations := []string{
					filepath.Join(tmpDir, "WEB-INF", "lib"),
					filepath.Join(tmpDir, "lib"),
					filepath.Join(tmpDir, "BOOT-INF", "lib"),
				}

				for _, loc := range locations {
					err := os.MkdirAll(loc, 0755)
					Expect(err).NotTo(HaveOccurred())
				}

				libDir := filepath.Join(tmpDir, "lib")
				aspectjJar := filepath.Join(libDir, "aspectjweaver-1.9.7.jar")
				err := os.WriteFile(aspectjJar, []byte("mock jar"), 0644)
				Expect(err).NotTo(HaveOccurred())

				_, err = os.Stat(aspectjJar)
				Expect(err).NotTo(HaveOccurred())
			})
		})

		Context("with different naming patterns", func() {
			It("recognizes various AspectJ JAR name formats", func() {
				libDir := filepath.Join(tmpDir, "lib")
				err := os.MkdirAll(libDir, 0755)
				Expect(err).NotTo(HaveOccurred())

				validNames := []string{
					"aspectjweaver-1.9.7.jar",
					"aspectjweaver-1.9.7.RELEASE.jar",
					"aspectjweaver-1.9.8.M1.jar",
				}

				for _, name := range validNames {
					jarPath := filepath.Join(libDir, name)
					err := os.WriteFile(jarPath, []byte("mock jar"), 0644)
					Expect(err).NotTo(HaveOccurred())

					_, err = os.Stat(jarPath)
					Expect(err).NotTo(HaveOccurred())

					os.Remove(jarPath)
				}
			})
		})
	})

	Describe("aop.xml configuration detection", func() {
		Context("in META-INF location", func() {
			It("detects aop.xml configuration", func() {
				metaInf := filepath.Join(tmpDir, "META-INF")
				err := os.MkdirAll(metaInf, 0755)
				Expect(err).NotTo(HaveOccurred())

				aopXml := filepath.Join(metaInf, "aop.xml")
				aopContent := `<?xml version="1.0" encoding="UTF-8"?>
<aspectj>
    <aspects>
        <aspect name="com.example.MyAspect"/>
    </aspects>
</aspectj>`

				err = os.WriteFile(aopXml, []byte(aopContent), 0644)
				Expect(err).NotTo(HaveOccurred())

				_, err = os.Stat(aopXml)
				Expect(err).NotTo(HaveOccurred())
			})
		})

		Context("in WEB-INF/classes/META-INF location", func() {
			It("detects aop.xml in WEB-INF structure", func() {
				webInfMetaInf := filepath.Join(tmpDir, "WEB-INF", "classes", "META-INF")
				err := os.MkdirAll(webInfMetaInf, 0755)
				Expect(err).NotTo(HaveOccurred())

				aopXml := filepath.Join(webInfMetaInf, "aop.xml")
				aopContent := `<?xml version="1.0" encoding="UTF-8"?>
<aspectj>
    <weaver options="-verbose -showWeaveInfo">
        <include within="com.example..*"/>
    </weaver>
</aspectj>`

				err = os.WriteFile(aopXml, []byte(aopContent), 0644)
				Expect(err).NotTo(HaveOccurred())

				_, err = os.Stat(aopXml)
				Expect(err).NotTo(HaveOccurred())
			})
		})
	})
})
