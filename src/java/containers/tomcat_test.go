package containers_test

import (
	"os"
	"path/filepath"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/containers"
	"github.com/cloudfoundry/libbuildpack"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Tomcat Container", func() {
	var (
		ctx       *common.Context
		container *containers.TomcatContainer
		buildDir  string
		depsDir   string
		cacheDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "build")
		Expect(err).NotTo(HaveOccurred())

		depsDir, err = os.MkdirTemp("", "deps")
		Expect(err).NotTo(HaveOccurred())

		cacheDir, err = os.MkdirTemp("", "cache")
		Expect(err).NotTo(HaveOccurred())

		// Create deps directory structure
		err = os.MkdirAll(filepath.Join(depsDir, "0"), 0755)
		Expect(err).NotTo(HaveOccurred())

		logger := libbuildpack.NewLogger(os.Stdout)
		manifest := &libbuildpack.Manifest{}
		installer := &libbuildpack.Installer{}
		stager := libbuildpack.NewStager([]string{buildDir, cacheDir, depsDir, "0"}, logger, manifest)
		command := &libbuildpack.Command{}

		ctx = &common.Context{
			Stager:    stager,
			Manifest:  manifest,
			Installer: installer,
			Log:       logger,
			Command:   command,
		}

		container = containers.NewTomcatContainer(ctx)
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(depsDir)
		os.RemoveAll(cacheDir)
	})

	Describe("Detect", func() {
		Context("with WEB-INF directory", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "WEB-INF"), 0755)
			})

			It("detects as Tomcat", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Tomcat"))
			})
		})

		Context("with WAR file", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "app.war"), []byte{}, 0644)
			})

			It("detects as Tomcat", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Tomcat"))
			})
		})

		Context("with two WAR files", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "app1.war"), []byte("fake"), 0644)
				os.WriteFile(filepath.Join(buildDir, "app2.war"), []byte("fake"), 0644)
			})

			It("detects as Tomcat", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Tomcat"))
			})
		})
	})

	Describe("Release", func() {
		BeforeEach(func() {
			os.MkdirAll(filepath.Join(buildDir, "WEB-INF"), 0755)
			container.Detect()
		})

		It("returns Tomcat startup command using CATALINA_HOME", func() {
			cmd, err := container.Release()
			Expect(err).NotTo(HaveOccurred())
			Expect(cmd).To(ContainSubstring("CATALINA_HOME"))
			Expect(cmd).To(ContainSubstring("catalina.sh run"))
		})
	})

	Describe("Finalize", func() {
		BeforeEach(func() {
			os.MkdirAll(filepath.Join(buildDir, "WEB-INF"), 0755)

			// Create mock Tomcat directory structure (after stripping top-level directory)
			tomcatDir := filepath.Join(depsDir, "0", "tomcat")
			os.MkdirAll(filepath.Join(tomcatDir, "bin"), 0755)
			os.MkdirAll(filepath.Join(tomcatDir, "conf"), 0755)
			os.WriteFile(filepath.Join(tomcatDir, "bin", "catalina.sh"), []byte("#!/bin/sh"), 0755)

			container.Detect()
		})

		It("finalizes successfully without META-INF/context.xml", func() {
			err := container.Finalize()
			Expect(err).NotTo(HaveOccurred())

			tomcatDir := filepath.Join(depsDir, "0", "tomcat")
			contextFile := filepath.Join(tomcatDir, "conf", "Catalina", "localhost", "ROOT.xml")
			Expect(contextFile).To(BeAnExistingFile())

			content, err := os.ReadFile(contextFile)
			Expect(err).NotTo(HaveOccurred())
			Expect(string(content)).To(ContainSubstring("docBase=\"${user.home}/app\""))
			Expect(string(content)).To(ContainSubstring("reloadable=\"false\""))
		})

		It("merges META-INF/context.xml with realm configuration", func() {
			metaInfDir := filepath.Join(buildDir, "META-INF")
			os.MkdirAll(metaInfDir, 0755)

			contextXML := `<?xml version="1.0" encoding="UTF-8"?>
<Context>
  <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
         resourceName="UserDatabase"/>
  <Resource name="jdbc/TestDB"
            auth="Container"
            type="javax.sql.DataSource"/>
</Context>`
			os.WriteFile(filepath.Join(metaInfDir, "context.xml"), []byte(contextXML), 0644)

			err := container.Finalize()
			Expect(err).NotTo(HaveOccurred())

			tomcatDir := filepath.Join(depsDir, "0", "tomcat")
			contextFile := filepath.Join(tomcatDir, "conf", "Catalina", "localhost", "ROOT.xml")
			Expect(contextFile).To(BeAnExistingFile())

			content, err := os.ReadFile(contextFile)
			Expect(err).NotTo(HaveOccurred())
			contentStr := string(content)

			Expect(contentStr).To(ContainSubstring("docBase=\"${user.home}/app\""))
			Expect(contentStr).To(ContainSubstring("org.apache.catalina.realm.UserDatabaseRealm"))
			Expect(contentStr).To(ContainSubstring("resourceName=\"UserDatabase\""))
			Expect(contentStr).To(ContainSubstring("jdbc/TestDB"))
			Expect(contentStr).To(ContainSubstring("javax.sql.DataSource"))
		})

		It("handles META-INF/context.xml with existing docBase attribute", func() {
			metaInfDir := filepath.Join(buildDir, "META-INF")
			os.MkdirAll(metaInfDir, 0755)

			contextXML := `<?xml version="1.0" encoding="UTF-8"?>
<Context docBase="/old/path" reloadable="true">
  <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
         resourceName="UserDatabase"/>
</Context>`
			os.WriteFile(filepath.Join(metaInfDir, "context.xml"), []byte(contextXML), 0644)

			err := container.Finalize()
			Expect(err).NotTo(HaveOccurred())

			tomcatDir := filepath.Join(depsDir, "0", "tomcat")
			contextFile := filepath.Join(tomcatDir, "conf", "Catalina", "localhost", "ROOT.xml")

			content, err := os.ReadFile(contextFile)
			Expect(err).NotTo(HaveOccurred())
			contentStr := string(content)

			Expect(contentStr).To(ContainSubstring("docBase=\"${user.home}/app\""))
			Expect(contentStr).NotTo(ContainSubstring("/old/path"))
			Expect(contentStr).To(ContainSubstring("org.apache.catalina.realm.UserDatabaseRealm"))
		})

		It("creates context XML named after context_path when set", func() {
			os.Setenv("JBP_CONFIG_TOMCAT", `{tomcat: {context_path: /the/intended/path}}`)
			defer os.Unsetenv("JBP_CONFIG_TOMCAT")

			err := container.Finalize()
			Expect(err).NotTo(HaveOccurred())

			tomcatDir := filepath.Join(depsDir, "0", "tomcat")
			contextFile := filepath.Join(tomcatDir, "conf", "Catalina", "localhost", "the#intended#path.xml")
			Expect(contextFile).To(BeAnExistingFile())
			Expect(filepath.Join(tomcatDir, "conf", "Catalina", "localhost", "ROOT.xml")).NotTo(BeAnExistingFile())

			content, err := os.ReadFile(contextFile)
			Expect(err).NotTo(HaveOccurred())
			Expect(string(content)).To(ContainSubstring("docBase=\"${user.home}/app\""))
		})

		It("uses ROOT.xml when context_path is empty", func() {
			err := container.Finalize()
			Expect(err).NotTo(HaveOccurred())

			tomcatDir := filepath.Join(depsDir, "0", "tomcat")
			Expect(filepath.Join(tomcatDir, "conf", "Catalina", "localhost", "ROOT.xml")).To(BeAnExistingFile())
		})

		It("uses ROOT.xml when context_path is /", func() {
			os.Setenv("JBP_CONFIG_TOMCAT", `{tomcat: {context_path: /}}`)
			defer os.Unsetenv("JBP_CONFIG_TOMCAT")

			err := container.Finalize()
			Expect(err).NotTo(HaveOccurred())

			tomcatDir := filepath.Join(depsDir, "0", "tomcat")
			Expect(filepath.Join(tomcatDir, "conf", "Catalina", "localhost", "ROOT.xml")).To(BeAnExistingFile())
		})
	})

	Describe("SelectTomcatVersionPattern", func() {
		var javaHome string

		BeforeEach(func() {
			var err error
			javaHome, err = os.MkdirTemp("", "javahome")
			Expect(err).NotTo(HaveOccurred())
		})

		AfterEach(func() {
			os.RemoveAll(javaHome)
		})

		writeReleaseFile := func(content string) {
			err := os.WriteFile(filepath.Join(javaHome, "release"), []byte(content), 0644)
			Expect(err).NotTo(HaveOccurred())
		}

		Context("when release file is missing", func() {
			It("returns empty pattern to fall back to manifest default, not assume Java 17", func() {
				pattern, err := containers.SelectTomcatVersionPattern(javaHome, "")
				Expect(err).NotTo(HaveOccurred())
				Expect(pattern).To(Equal(""))
			})

			It("still honours an explicitly configured tomcat version", func() {
				pattern, err := containers.SelectTomcatVersionPattern(javaHome, "9.*")
				Expect(err).NotTo(HaveOccurred())
				Expect(pattern).To(Equal("9.*"))
			})
		})

		Context("happy path version selection", func() {
			It("selects Tomcat 10.x for Java 11+", func() {
				writeReleaseFile("JAVA_VERSION=\"11.0.20\"\n")
				pattern, err := containers.SelectTomcatVersionPattern(javaHome, "")
				Expect(err).NotTo(HaveOccurred())
				Expect(pattern).To(Equal("10.x"))
			})

			It("selects Tomcat 9.x for Java 8", func() {
				writeReleaseFile("JAVA_VERSION=\"1.8.0_372\"\n")
				pattern, err := containers.SelectTomcatVersionPattern(javaHome, "")
				Expect(err).NotTo(HaveOccurred())
				Expect(pattern).To(Equal("9.x"))
			})

			It("errors when Tomcat 10.x is requested but Java 8 detected", func() {
				writeReleaseFile("JAVA_VERSION=\"1.8.0_372\"\n")
				_, err := containers.SelectTomcatVersionPattern(javaHome, "10.*")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("Java 11+"))
			})
		})
	})

	Describe("determineTomcatVersion", func() {
		It("returns empty string when JBP_CONFIG_TOMCAT is empty", func() {
			v := containers.DetermineTomcatVersion("")
			Expect(v).To(Equal(""))
		})

		It("returns 9.* for tomcat version 9.+", func() {
			raw := `9.+`
			v := containers.DetermineTomcatVersion(raw)
			Expect(v).To(Equal("9.*"))
		})

		It("returns 10.* for tomcat version 10.+", func() {
			raw := `10.+`
			v := containers.DetermineTomcatVersion(raw)
			Expect(v).To(Equal("10.*"))
		})

		It("returns 10.1.* for tomcat version 10.1.+", func() {
			raw := `10.1.+`
			v := containers.DetermineTomcatVersion(raw)
			Expect(v).To(Equal("10.1.*"))
		})
	})
})
