package jres_test

import (
	"bytes"
	"os"
	"path/filepath"
	"time"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/jres"
	"github.com/cloudfoundry/libbuildpack"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("JRE Registry", func() {
	var (
		ctx       *common.Context
		registry  *jres.Registry
		buildDir  string
		depsDir   string
		cacheDir  string
		logBuffer *bytes.Buffer
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
		err = os.MkdirAll(depsDir+"/0", 0755)
		Expect(err).NotTo(HaveOccurred())

		logBuffer = &bytes.Buffer{}
		logger := libbuildpack.NewLogger(logBuffer)
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

		registry = jres.NewRegistry(ctx)
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(depsDir)
		os.RemoveAll(cacheDir)
	})

	Describe("Registry Creation", func() {
		It("creates a registry successfully", func() {
			Expect(registry).NotTo(BeNil())
		})

		It("returns error when no JREs registered", func() {
			jre, name, err := registry.Detect()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("no JRE found"))
			Expect(jre).To(BeNil())
			Expect(name).To(BeEmpty())
		})
	})

	Describe("Register and Detect", func() {
		BeforeEach(func() {
			// Register OpenJDK JRE and set it as default
			openJDK := jres.NewOpenJDKJRE(ctx)
			registry.Register(openJDK)
			registry.SetDefault(openJDK)
		})

		It("detects registered JREs", func() {
			jre, name, err := registry.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(jre).NotTo(BeNil())
			Expect(name).To(Equal("OpenJDK"))
		})
	})

	Describe("Multiple JREs", func() {
		It("returns default JRE when none explicitly configured", func() {
			// Register OpenJDK and set as default (mimics production usage)
			openJDK := jres.NewOpenJDKJRE(ctx)
			registry.Register(openJDK)
			registry.SetDefault(openJDK)

			jre, name, err := registry.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(jre).NotTo(BeNil())
			Expect(name).To(Equal("OpenJDK"))
		})

		It("returns explicitly configured JRE over default", func() {
			// Setup: Configure SapMachine via environment
			os.Setenv("JBP_CONFIG_SAP_MACHINE_JRE", "{jre: {version: 17.+}}")
			defer os.Unsetenv("JBP_CONFIG_SAP_MACHINE_JRE")

			// Register all standard JREs (mimics production)
			registry.RegisterStandardJREs()

			// Should detect SapMachine, not OpenJDK
			jre, name, err := registry.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(jre).NotTo(BeNil())
			Expect(name).To(Equal("SapMachine"))
		})
	})
})

var _ = Describe("JRE Helper Functions", func() {
	var (
		ctx      *common.Context
		buildDir string
		depsDir  string
		cacheDir string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "build")
		Expect(err).NotTo(HaveOccurred())

		depsDir, err = os.MkdirTemp("", "deps")
		Expect(err).NotTo(HaveOccurred())

		cacheDir, err = os.MkdirTemp("", "cache")
		Expect(err).NotTo(HaveOccurred())

		// Set CF_STACK for manifest dependency filtering
		os.Setenv("CF_STACK", "cflinuxfs4")

		logger := libbuildpack.NewLogger(GinkgoWriter)

		// Create manifest directory with required files
		manifestDir, err := os.MkdirTemp("", "manifest")
		Expect(err).NotTo(HaveOccurred())

		versionFile := manifestDir + "/VERSION"
		Expect(os.WriteFile(versionFile, []byte("1.0.0"), 0644)).To(Succeed())

		manifestFile := manifestDir + "/manifest.yml"
		manifestContent := `---
language: java
default_versions:
- name: openjdk
  version: 17.x
- name: sapmachine
  version: 21.x
- name: zulu
  version: 11.x
dependencies:
- name: openjdk
  version: 8.0.422
  uri: https://example.com/openjdk-8.tar.gz
  sha256: 0000000000000000000000000000000000000000000000000000000000000000
  cf_stacks:
  - cflinuxfs4
- name: openjdk
  version: 11.0.25
  uri: https://example.com/openjdk-11.tar.gz
  sha256: 1111111111111111111111111111111111111111111111111111111111111111
  cf_stacks:
  - cflinuxfs4
- name: openjdk
  version: 17.0.13
  uri: https://example.com/openjdk-17.tar.gz
  sha256: 2222222222222222222222222222222222222222222222222222222222222222
  cf_stacks:
  - cflinuxfs4
- name: openjdk
  version: 21.0.5
  uri: https://example.com/openjdk-21.tar.gz
  sha256: 3333333333333333333333333333333333333333333333333333333333333333
  cf_stacks:
  - cflinuxfs4
- name: sapmachine
  version: 17.0.17
  uri: https://github.com/SAP/SapMachine/releases/download/sapmachine-17.0.17/sapmachine-jre-17.0.17_linux-x64_bin.tar.gz
  sha256: c45d572629c722b18a6254f7503a397dbfe474223afb3ac96ef462d27074f7a0
  cf_stacks:
  - cflinuxfs4
- name: sapmachine
  version: 21.0.9
  uri: https://github.com/SAP/SapMachine/releases/download/sapmachine-21.0.9/sapmachine-jre-21.0.9_linux-x64_bin.tar.gz
  sha256: 4cc6b1501a2fe8ae0f106342b3c00eec00b7886ce9215760b611cc9975bd339b
  cf_stacks:
  - cflinuxfs4
- name: sapmachine
  version: 25.0.1
  uri: https://github.com/SAP/SapMachine/releases/download/sapmachine-25.0.1/sapmachine-jre-25.0.1_linux-x64_bin.tar.gz
  sha256: 6bc007201b97214a3883e2da92dc80b2e5ae29378a7a77ab4077d74ccbfdfdbd
  cf_stacks:
  - cflinuxfs4
- name: zulu
  version: 11.0.25
  uri: https://cdn.azul.com/zulu/bin/zulu11.76.21-ca-jre11.0.25-linux_x64.tar.gz
  sha256: 2696d23e20a7e6cc22d36a27c3d917b6b390d0e6ac1819e791d99a1fc159317c
  cf_stacks:
  - cflinuxfs4
- name: zulu
  version: 17.0.13
  uri: https://cdn.azul.com/zulu/bin/zulu17.54.21-ca-jre17.0.13-linux_x64.tar.gz
  sha256: 2d74f026d0d184075ad99de343c6a24bd702eb25d87ce6de5e3ab8df1cd3ef25
  cf_stacks:
  - cflinuxfs4
`
		Expect(os.WriteFile(manifestFile, []byte(manifestContent), 0644)).To(Succeed())

		manifest, err := libbuildpack.NewManifest(manifestDir, logger, time.Now())
		Expect(err).NotTo(HaveOccurred())

		stager := libbuildpack.NewStager([]string{buildDir, cacheDir, depsDir, "0"}, logger, manifest)

		ctx = &common.Context{
			Stager:    stager,
			Manifest:  manifest,
			Installer: &libbuildpack.Installer{},
			Log:       logger,
			Command:   &libbuildpack.Command{},
		}
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(depsDir)
		os.RemoveAll(cacheDir)
		os.Unsetenv("BP_JAVA_VERSION")
		os.Unsetenv("JBP_CONFIG_OPEN_JDK_JRE")
		os.Unsetenv("CF_STACK")
	})

	Describe("DetectJREByEnv", func() {
		It("returns false when environment variable is not set", func() {
			detected := jres.DetectJREByEnv("openjdk")
			Expect(detected).To(BeFalse())
		})

		It("returns true when documented environment variable is set", func() {
			os.Setenv("JBP_CONFIG_OPEN_JDK_JRE", "{jre: {version: 17.+}}")
			defer os.Unsetenv("JBP_CONFIG_OPEN_JDK_JRE")
			detected := jres.DetectJREByEnv("openjdk")
			Expect(detected).To(BeTrue())
		})

		It("returns true for SapMachine when JBP_CONFIG_SAP_MACHINE_JRE is set", func() {
			os.Setenv("JBP_CONFIG_SAP_MACHINE_JRE", "{jre: {version: 17.+}}")
			defer os.Unsetenv("JBP_CONFIG_SAP_MACHINE_JRE")
			detected := jres.DetectJREByEnv("sapmachine")
			Expect(detected).To(BeTrue())
		})

		It("returns true for Zulu when JBP_CONFIG_ZULU_JRE is set", func() {
			os.Setenv("JBP_CONFIG_ZULU_JRE", "{jre: {version: 17.+}}")
			defer os.Unsetenv("JBP_CONFIG_ZULU_JRE")
			detected := jres.DetectJREByEnv("zulu")
			Expect(detected).To(BeTrue())
		})
	})

	Describe("GetJREVersion", func() {
		Context("with BP_JAVA_VERSION environment variable", func() {
			It("resolves major version 8", func() {
				os.Setenv("BP_JAVA_VERSION", "8")
				dep, err := jres.GetJREVersion(ctx, "openjdk")
				Expect(err).NotTo(HaveOccurred())
				Expect(dep.Name).To(Equal("openjdk"))
				Expect(dep.Version).To(Equal("8.0.422"))
			})

			It("resolves major version 11", func() {
				os.Setenv("BP_JAVA_VERSION", "11")
				dep, err := jres.GetJREVersion(ctx, "openjdk")
				Expect(err).NotTo(HaveOccurred())
				Expect(dep.Name).To(Equal("openjdk"))
				Expect(dep.Version).To(Equal("11.0.25"))
			})

			It("resolves major version 17", func() {
				os.Setenv("BP_JAVA_VERSION", "17")
				dep, err := jres.GetJREVersion(ctx, "openjdk")
				Expect(err).NotTo(HaveOccurred())
				Expect(dep.Name).To(Equal("openjdk"))
				Expect(dep.Version).To(Equal("17.0.13"))
			})

			It("resolves major version 21", func() {
				os.Setenv("BP_JAVA_VERSION", "21")
				dep, err := jres.GetJREVersion(ctx, "openjdk")
				Expect(err).NotTo(HaveOccurred())
				Expect(dep.Name).To(Equal("openjdk"))
				Expect(dep.Version).To(Equal("21.0.5"))
			})

			It("handles version patterns with wildcards", func() {
				os.Setenv("BP_JAVA_VERSION", "17.*")
				dep, err := jres.GetJREVersion(ctx, "openjdk")
				Expect(err).NotTo(HaveOccurred())
				Expect(dep.Name).To(Equal("openjdk"))
				Expect(dep.Version).To(Equal("17.0.13"))
			})
		})

		Context("without BP_JAVA_VERSION", func() {
			It("returns default version from manifest", func() {
				dep, err := jres.GetJREVersion(ctx, "openjdk")
				Expect(err).NotTo(HaveOccurred())
				Expect(dep.Name).To(Equal("openjdk"))
				Expect(dep.Version).To(ContainSubstring("17."))
			})
		})

		Context("with JBP_CONFIG_OPENJDK", func() {
			AfterEach(func() {
				os.Unsetenv("JBP_CONFIG_OPENJDK")
			})

			It("resolves version from JBP_CONFIG", func() {
				os.Setenv("JBP_CONFIG_OPENJDK", "{jre: {version: 11.+}}")
				dep, err := jres.GetJREVersion(ctx, "openjdk")
				Expect(err).NotTo(HaveOccurred())
				Expect(dep.Name).To(Equal("openjdk"))
				Expect(dep.Version).To(Equal("11.0.25"))
			})

			It("fails when requested version does not exist", func() {
				os.Setenv("JBP_CONFIG_OPENJDK", "{jre: {version: 99.+}}")
				_, err := jres.GetJREVersion(ctx, "openjdk")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no version of openjdk matching"))
			})

			It("fails when config format is invalid", func() {
				os.Setenv("JBP_CONFIG_OPENJDK", "invalid config")
				_, err := jres.GetJREVersion(ctx, "openjdk")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("could not parse version"))
			})
		})

		Context("with JBP_CONFIG_OPEN_JDK_JRE", func() {
			AfterEach(func() {
				os.Unsetenv("JBP_CONFIG_OPEN_JDK_JRE")
			})

			It("resolves version 21.+ pattern", func() {
				os.Setenv("JBP_CONFIG_OPEN_JDK_JRE", "{jre: {version: 21.+}}")
				dep, err := jres.GetJREVersion(ctx, "openjdk")
				Expect(err).NotTo(HaveOccurred())
				Expect(dep.Name).To(Equal("openjdk"))
				Expect(dep.Version).To(Equal("21.0.5"))
			})

			It("resolves version 17.+ pattern", func() {
				os.Setenv("JBP_CONFIG_OPEN_JDK_JRE", "{jre: {version: 17.+}}")
				dep, err := jres.GetJREVersion(ctx, "openjdk")
				Expect(err).NotTo(HaveOccurred())
				Expect(dep.Name).To(Equal("openjdk"))
				Expect(dep.Version).To(Equal("17.0.13"))
			})

			It("resolves version 11.+ pattern", func() {
				os.Setenv("JBP_CONFIG_OPEN_JDK_JRE", "{jre: {version: 11.+}}")
				dep, err := jres.GetJREVersion(ctx, "openjdk")
				Expect(err).NotTo(HaveOccurred())
				Expect(dep.Name).To(Equal("openjdk"))
				Expect(dep.Version).To(Equal("11.0.25"))
			})

			It("fails when requested version does not exist", func() {
				os.Setenv("JBP_CONFIG_OPEN_JDK_JRE", "{jre: {version: 99.+}}")
				_, err := jres.GetJREVersion(ctx, "openjdk")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no version of openjdk matching"))
			})

			It("prefers JBP_CONFIG_OPEN_JDK_JRE over default when both are unset", func() {
				os.Setenv("JBP_CONFIG_OPEN_JDK_JRE", "{jre: {version: 21.+}}")
				dep, err := jres.GetJREVersion(ctx, "openjdk")
				Expect(err).NotTo(HaveOccurred())
				Expect(dep.Version).To(Equal("21.0.5"))
			})
		})

		Context("documented environment variables for all JREs", func() {
			It("should resolve JBP_CONFIG_SAP_MACHINE_JRE for SAPMachine", func() {
				os.Setenv("JBP_CONFIG_SAP_MACHINE_JRE", "{ jre: {version: 17.+} }")
				defer os.Unsetenv("JBP_CONFIG_SAP_MACHINE_JRE")

				dep, err := jres.GetJREVersion(ctx, "sapmachine")
				Expect(err).NotTo(HaveOccurred())
				Expect(dep.Name).To(Equal("sapmachine"))
				Expect(dep.Version).To(Equal("17.0.17"))
			})

			It("should resolve JBP_CONFIG_SAP_MACHINE_JRE for SAPMachine", func() {
				os.Setenv("JBP_CONFIG_SAP_MACHINE_JRE", "{ jre: {version: 21.+} }")
				defer os.Unsetenv("JBP_CONFIG_SAP_MACHINE_JRE")

				dep, err := jres.GetJREVersion(ctx, "sapmachine")
				Expect(err).NotTo(HaveOccurred())
				Expect(dep.Name).To(Equal("sapmachine"))
				Expect(dep.Version).To(Equal("21.0.9"))
			})

			It("should resolve JBP_CONFIG_SAP_MACHINE_JRE for SAPMachine", func() {
				os.Setenv("JBP_CONFIG_SAP_MACHINE_JRE", "{ jre: {version: 25.+} }")
				defer os.Unsetenv("JBP_CONFIG_SAP_MACHINE_JRE")

				dep, err := jres.GetJREVersion(ctx, "sapmachine")
				Expect(err).NotTo(HaveOccurred())
				Expect(dep.Name).To(Equal("sapmachine"))
				Expect(dep.Version).To(Equal("25.0.1"))
			})

			It("should resolve JBP_CONFIG_SAP_MACHINE_JRE for SAPMachine", func() {
				os.Setenv("JBP_CONFIG_SAP_MACHINE_JRE", "{ jre: {version: 26.+} }")
				defer os.Unsetenv("JBP_CONFIG_SAP_MACHINE_JRE")

				_, err := jres.GetJREVersion(ctx, "sapmachine")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no version of sapmachine matching '26.+' found in manifest"))
			})

			It("should resolve JBP_CONFIG_ZULU_JRE for Zulu", func() {
				os.Setenv("JBP_CONFIG_ZULU_JRE", "{jre: {version: 11.+}}")
				defer os.Unsetenv("JBP_CONFIG_ZULU_JRE")

				dep, err := jres.GetJREVersion(ctx, "zulu")
				Expect(err).NotTo(HaveOccurred())
				Expect(dep.Name).To(Equal("zulu"))
				Expect(dep.Version).To(Equal("11.0.25"))
			})

			It("should resolve JBP_CONFIG_ZULU_JRE for Zulu", func() {
				os.Setenv("JBP_CONFIG_ZULU_JRE", "{jre: {version: 17.+}}")
				defer os.Unsetenv("JBP_CONFIG_ZULU_JRE")

				dep, err := jres.GetJREVersion(ctx, "zulu")
				Expect(err).NotTo(HaveOccurred())
				Expect(dep.Name).To(Equal("zulu"))
				Expect(dep.Version).To(Equal("17.0.13"))
			})

			It("should resolve JBP_CONFIG_ZULU_JRE for Zulu", func() {
				os.Setenv("JBP_CONFIG_ZULU_JRE", "{jre: {version: 18.+}}")
				defer os.Unsetenv("JBP_CONFIG_ZULU_JRE")

				_, err := jres.GetJREVersion(ctx, "zulu")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no version of zulu matching '18.+' found in manifest"))
			})

			It("should resolve JBP_CONFIG_GRAAL_VM_JRE for GraalVM", func() {
				os.Setenv("JBP_CONFIG_GRAAL_VM_JRE", "{jre: {version: 22.1.+}}")
				defer os.Unsetenv("JBP_CONFIG_GRAAL_VM_JRE")

				_, err := jres.GetJREVersion(ctx, "graalvm")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no versions of graalvm found"))
			})

			It("should resolve JBP_CONFIG_IBM_JRE for IBM", func() {
				os.Setenv("JBP_CONFIG_IBM_JRE", "{jre: {version: 1.8.+}}")
				defer os.Unsetenv("JBP_CONFIG_IBM_JRE")

				_, err := jres.GetJREVersion(ctx, "ibm")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no versions of ibm found"))
			})

			It("should resolve JBP_CONFIG_ORACLE_JRE for Oracle", func() {
				os.Setenv("JBP_CONFIG_ORACLE_JRE", "{jre: {version: 17.+}}")
				defer os.Unsetenv("JBP_CONFIG_ORACLE_JRE")

				_, err := jres.GetJREVersion(ctx, "oracle")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no versions of oracle found"))
			})

			It("should resolve JBP_CONFIG_ZING_JRE for Zing", func() {
				os.Setenv("JBP_CONFIG_ZING_JRE", "{jre: {version: 17.+}}")
				defer os.Unsetenv("JBP_CONFIG_ZING_JRE")

				_, err := jres.GetJREVersion(ctx, "zing")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no versions of zing found"))
			})
		})
	})

	Describe("DetermineJavaVersion", func() {
		var javaHome string

		BeforeEach(func() {
			var err error
			javaHome, err = os.MkdirTemp("", "javahome")
			Expect(err).NotTo(HaveOccurred())
		})

		AfterEach(func() {
			os.RemoveAll(javaHome)
		})

		It("detects Java 8 from release file", func() {
			releaseContent := `JAVA_VERSION="1.8.0_422"
IMPLEMENTOR="Eclipse Adoptium"`
			releaseFile := javaHome + "/release"
			Expect(os.WriteFile(releaseFile, []byte(releaseContent), 0644)).To(Succeed())

			version, err := common.DetermineJavaVersion(javaHome)
			Expect(err).NotTo(HaveOccurred())
			Expect(version).To(Equal(8))
		})

		It("detects Java 11 from release file", func() {
			releaseContent := `JAVA_VERSION="11.0.25"
IMPLEMENTOR="Eclipse Adoptium"`
			releaseFile := javaHome + "/release"
			Expect(os.WriteFile(releaseFile, []byte(releaseContent), 0644)).To(Succeed())

			version, err := common.DetermineJavaVersion(javaHome)
			Expect(err).NotTo(HaveOccurred())
			Expect(version).To(Equal(11))
		})

		It("detects Java 17 from release file", func() {
			releaseContent := `JAVA_VERSION="17.0.13"
IMPLEMENTOR="Eclipse Adoptium"`
			releaseFile := javaHome + "/release"
			Expect(os.WriteFile(releaseFile, []byte(releaseContent), 0644)).To(Succeed())

			version, err := common.DetermineJavaVersion(javaHome)
			Expect(err).NotTo(HaveOccurred())
			Expect(version).To(Equal(17))
		})

		It("detects Java 21 from release file", func() {
			releaseContent := `JAVA_VERSION="21.0.5"
IMPLEMENTOR="Eclipse Adoptium"`
			releaseFile := javaHome + "/release"
			Expect(os.WriteFile(releaseFile, []byte(releaseContent), 0644)).To(Succeed())

			version, err := common.DetermineJavaVersion(javaHome)
			Expect(err).NotTo(HaveOccurred())
			Expect(version).To(Equal(21))
		})

		It("defaults to 17 when release file is missing", func() {
			version, err := common.DetermineJavaVersion(javaHome)
			Expect(err).NotTo(HaveOccurred())
			Expect(version).To(Equal(17))
		})
	})

	Describe("WriteJavaOpts", func() {
		It("writes JAVA_OPTS to .opts file with priority 05", func() {
			opts := "-Xmx512m -Xms256m"
			err := jres.WriteJavaOpts(ctx, opts)
			Expect(err).NotTo(HaveOccurred())

			// Check that .opts file was created in deps/0/java_opts/05_jre.opts
			optsFile := filepath.Join(depsDir, "0", "java_opts", "05_jre.opts")
			Expect(optsFile).To(BeAnExistingFile())

			content, err := os.ReadFile(optsFile)
			Expect(err).NotTo(HaveOccurred())
			Expect(string(content)).To(ContainSubstring(opts))
		})

		It("creates java_opts directory if it doesn't exist", func() {
			opts := "-verbose:gc"
			err := jres.WriteJavaOpts(ctx, opts)
			Expect(err).NotTo(HaveOccurred())

			optsFile := filepath.Join(depsDir, "0", "java_opts", "05_jre.opts")
			Expect(optsFile).To(BeAnExistingFile())
		})
	})

	Describe("JRE Detection with Environment Variables (Ruby buildpack compatibility)", func() {
		var testLogBuffer *bytes.Buffer
		var testCtx *common.Context

		BeforeEach(func() {
			testLogBuffer = &bytes.Buffer{}
			logger := libbuildpack.NewLogger(testLogBuffer)
			manifest := &libbuildpack.Manifest{}
			installer := &libbuildpack.Installer{}
			stager := libbuildpack.NewStager([]string{buildDir, cacheDir, depsDir, "0"}, logger, manifest)
			command := &libbuildpack.Command{}

			testCtx = &common.Context{
				Stager:    stager,
				Manifest:  manifest,
				Installer: installer,
				Log:       logger,
				Command:   command,
			}
		})

		It("detects SapMachine with only JBP_CONFIG_SAP_MACHINE_JRE (no JBP_CONFIG_COMPONENTS)", func() {
			os.Setenv("JBP_CONFIG_SAP_MACHINE_JRE", "{jre: {version: 17.+}}")
			defer os.Unsetenv("JBP_CONFIG_SAP_MACHINE_JRE")

			sapmachine := jres.NewSapMachineJRE(testCtx)
			detected, err := sapmachine.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(detected).To(BeTrue(), "SapMachine should be detected with JBP_CONFIG_SAP_MACHINE_JRE alone")
		})

		It("detects Zulu with only JBP_CONFIG_ZULU_JRE (no JBP_CONFIG_COMPONENTS)", func() {
			os.Setenv("JBP_CONFIG_ZULU_JRE", "{jre: {version: 17.+}}")
			defer os.Unsetenv("JBP_CONFIG_ZULU_JRE")

			zulu := jres.NewZuluJRE(testCtx)
			detected, err := zulu.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(detected).To(BeTrue(), "Zulu should be detected with JBP_CONFIG_ZULU_JRE alone")
		})

		It("detects OpenJDK with only JBP_CONFIG_OPEN_JDK_JRE (no JBP_CONFIG_COMPONENTS)", func() {
			os.Setenv("JBP_CONFIG_OPEN_JDK_JRE", "{jre: {version: 17.+}}")
			defer os.Unsetenv("JBP_CONFIG_OPEN_JDK_JRE")

			openjdk := jres.NewOpenJDKJRE(testCtx)
			detected, err := openjdk.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(detected).To(BeTrue(), "OpenJDK should be detected with JBP_CONFIG_OPEN_JDK_JRE alone")
		})

		It("uses JBP_CONFIG_SAP_MACHINE_JRE for SapMachine detection", func() {
			os.Setenv("JBP_CONFIG_SAP_MACHINE_JRE", "{jre: {version: 17.+}}")
			os.Setenv("JBP_CONFIG_OPEN_JDK_JRE", "{jre: {version: 17.+}}")
			defer os.Unsetenv("JBP_CONFIG_SAP_MACHINE_JRE")
			defer os.Unsetenv("JBP_CONFIG_OPEN_JDK_JRE")

			sapmachine := jres.NewSapMachineJRE(testCtx)
			detected, err := sapmachine.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(detected).To(BeTrue(), "SapMachine should be detected via JBP_CONFIG_SAP_MACHINE_JRE")

			openjdk := jres.NewOpenJDKJRE(testCtx)
			detected, err = openjdk.Detect()
			Expect(err).NotTo(HaveOccurred())
			Expect(detected).To(BeTrue(), "OpenJDK should also be detected via JBP_CONFIG_OPEN_JDK_JRE")
		})
	})
})
