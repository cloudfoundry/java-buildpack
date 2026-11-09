package frameworks_test

import (
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/frameworks"
	"github.com/cloudfoundry/libbuildpack"
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

	Describe("Detect and Finalize", func() {
		var framework *frameworks.AspectJWeaverAgentFramework

		BeforeEach(func() {
			logger := libbuildpack.NewLogger(GinkgoWriter)
			manifest := &libbuildpack.Manifest{}
			stager := libbuildpack.NewStager([]string{tmpDir, filepath.Join(tmpDir, "cache"), filepath.Join(tmpDir, "deps"), "0"}, logger, manifest)
			framework = frameworks.NewAspectJWeaverAgentFramework(&common.Context{
				Stager:    stager,
				Manifest:  manifest,
				Installer: &libbuildpack.Installer{},
				Log:       logger,
				Command:   &libbuildpack.Command{},
			})

			bootInfLib := filepath.Join(tmpDir, "BOOT-INF", "lib")
			Expect(os.MkdirAll(bootInfLib, 0755)).To(Succeed())
			Expect(os.WriteFile(filepath.Join(bootInfLib, "aspectjweaver-1.9.7.jar"), []byte("mock jar"), 0644)).To(Succeed())
		})

		writeAopXml := func(relativeDir ...string) {
			dir := filepath.Join(append([]string{tmpDir}, relativeDir...)...)
			Expect(os.MkdirAll(dir, 0755)).To(Succeed())
			Expect(os.WriteFile(filepath.Join(dir, "aop.xml"), []byte("<aspectj/>"), 0644)).To(Succeed())
		}

		It("returns nothing without aop.xml", func() {
			name, err := framework.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(name).To(BeEmpty())
		})

		DescribeTable("detects aop.xml location",
			func(relativeDir ...string) {
				writeAopXml(relativeDir...)

				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("aspectj-weaver"))
			},
			Entry("META-INF", "META-INF"),
			Entry("WEB-INF/classes/META-INF", "WEB-INF", "classes", "META-INF"),
			Entry("WEB-INF/classes/org/aspectj", "WEB-INF", "classes", "org", "aspectj"),
			Entry("BOOT-INF/classes/META-INF", "BOOT-INF", "classes", "META-INF"),
			Entry("BOOT-INF/classes/org/aspectj", "BOOT-INF", "classes", "org", "aspectj"),
			Entry("org/aspectj", "org", "aspectj"),
		)

		It("writes a javaagent opt pointing at the weaver jar under $HOME", func() {
			writeAopXml("BOOT-INF", "classes", "META-INF")

			name, err := framework.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(name).To(Equal("aspectj-weaver"))
			Expect(framework.Finalize()).To(Succeed())

			optsFile := filepath.Join(tmpDir, "deps", "0", "java_opts", "12_aspectj_weaver.opts")
			content, err := os.ReadFile(optsFile)
			Expect(err).NotTo(HaveOccurred())
			Expect(string(content)).To(Equal("-javaagent:$HOME/BOOT-INF/lib/aspectjweaver-1.9.7.jar"))
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
