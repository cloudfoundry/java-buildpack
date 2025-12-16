package jres_test

import (
	"os"
	"testing"
	"time"

	"github.com/cloudfoundry/java-buildpack/src/java/jres"
	"github.com/cloudfoundry/libbuildpack"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestJREs(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "JREs Suite")
}

var _ = Describe("JRE Registry", func() {
	var (
		ctx      *jres.Context
		registry *jres.Registry
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

		// Create deps directory structure
		err = os.MkdirAll(depsDir+"/0", 0755)
		Expect(err).NotTo(HaveOccurred())

		logger := libbuildpack.NewLogger(os.Stdout)
		manifest := &libbuildpack.Manifest{}
		installer := &libbuildpack.Installer{}
		stager := libbuildpack.NewStager([]string{buildDir, cacheDir, depsDir, "0"}, logger, manifest)
		command := &libbuildpack.Command{}

		ctx = &jres.Context{
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
		ctx      *jres.Context
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
`
		Expect(os.WriteFile(manifestFile, []byte(manifestContent), 0644)).To(Succeed())

		manifest, err := libbuildpack.NewManifest(manifestDir, logger, time.Now())
		Expect(err).NotTo(HaveOccurred())

		stager := libbuildpack.NewStager([]string{buildDir, cacheDir, depsDir, "0"}, logger, manifest)

		ctx = &jres.Context{
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
			detected := jres.DetectJREByEnv("open-jdk-jre")
			Expect(detected).To(BeFalse())
		})

		It("returns true when environment variable is set", func() {
			os.Setenv("JBP_CONFIG_OPEN_JDK_JRE", "{jre: {version: 17.+}}")
			detected := jres.DetectJREByEnv("open-jdk-jre")
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
				// Should match default version 17.x
				Expect(dep.Version).To(ContainSubstring("17."))
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

			version, err := jres.DetermineJavaVersion(javaHome)
			Expect(err).NotTo(HaveOccurred())
			Expect(version).To(Equal(8))
		})

		It("detects Java 11 from release file", func() {
			releaseContent := `JAVA_VERSION="11.0.25"
IMPLEMENTOR="Eclipse Adoptium"`
			releaseFile := javaHome + "/release"
			Expect(os.WriteFile(releaseFile, []byte(releaseContent), 0644)).To(Succeed())

			version, err := jres.DetermineJavaVersion(javaHome)
			Expect(err).NotTo(HaveOccurred())
			Expect(version).To(Equal(11))
		})

		It("detects Java 17 from release file", func() {
			releaseContent := `JAVA_VERSION="17.0.13"
IMPLEMENTOR="Eclipse Adoptium"`
			releaseFile := javaHome + "/release"
			Expect(os.WriteFile(releaseFile, []byte(releaseContent), 0644)).To(Succeed())

			version, err := jres.DetermineJavaVersion(javaHome)
			Expect(err).NotTo(HaveOccurred())
			Expect(version).To(Equal(17))
		})

		It("detects Java 21 from release file", func() {
			releaseContent := `JAVA_VERSION="21.0.5"
IMPLEMENTOR="Eclipse Adoptium"`
			releaseFile := javaHome + "/release"
			Expect(os.WriteFile(releaseFile, []byte(releaseContent), 0644)).To(Succeed())

			version, err := jres.DetermineJavaVersion(javaHome)
			Expect(err).NotTo(HaveOccurred())
			Expect(version).To(Equal(21))
		})

		It("defaults to 17 when release file is missing", func() {
			version, err := jres.DetermineJavaVersion(javaHome)
			Expect(err).NotTo(HaveOccurred())
			Expect(version).To(Equal(17))
		})
	})

	Describe("WriteJavaOpts", func() {
		It("writes JAVA_OPTS to profile.d script", func() {
			opts := "-Xmx512m -Xms256m"
			err := jres.WriteJavaOpts(ctx, opts)
			Expect(err).NotTo(HaveOccurred())

			profileScript := buildDir + "/.profile.d/java_opts.sh"
			Expect(profileScript).To(BeAnExistingFile())

			content, err := os.ReadFile(profileScript)
			Expect(err).NotTo(HaveOccurred())
			Expect(string(content)).To(ContainSubstring(opts))
			Expect(string(content)).To(ContainSubstring("export JAVA_OPTS="))
		})

		It("creates directory if it doesn't exist", func() {
			opts := "-verbose:gc"
			err := jres.WriteJavaOpts(ctx, opts)
			Expect(err).NotTo(HaveOccurred())

			profileScript := buildDir + "/.profile.d/java_opts.sh"
			Expect(profileScript).To(BeAnExistingFile())
		})
	})
})
