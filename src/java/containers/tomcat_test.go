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
	})

	Describe("determineTomcatVersion", func() {
		It("returns empty string when JBP_CONFIG_TOMCAT is empty", func() {
			v := containers.DetermineTomcatVersion("")
			Expect(v).To(Equal(""))
		})

		It("returns 9.x for tomcat version 9.+", func() {
			raw := `{ tomcat: { version: "9.+" } }`
			v := containers.DetermineTomcatVersion(raw)
			Expect(v).To(Equal("9.x"))
		})

		It("returns 10.x for tomcat version 10.+", func() {
			raw := `{ tomcat: { version: "10.+" } }`
			v := containers.DetermineTomcatVersion(raw)
			Expect(v).To(Equal("10.x"))
		})

		It("returns 10.23.+ for tomcat version 10.23.+", func() {
			raw := `{ tomcat: { version: "10.23.+" } }`
			v := containers.DetermineTomcatVersion(raw)
			Expect(v).To(Equal("10.23.+"))
		})

		It("returns empty string when only access logging is configured", func() {
			raw := `{access_logging_support: {access_logging: enabled}}`
			v := containers.DetermineTomcatVersion(raw)
			Expect(v).To(Equal(""))
		})
	})
})
