package jres_test

import (
	"os"
	"path/filepath"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/jres"
	"github.com/cloudfoundry/libbuildpack"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Standard JREs", func() {
	testCases := []struct {
		description string
		displayName string
		envVar      string
		otherEnvVar string
		subdir      string
		version     string
		newJRE      func(*common.Context) jres.JRE
	}{
		{
			description: "Zulu",
			displayName: "Zulu",
			envVar:      "JBP_CONFIG_ZULU_JRE",
			otherEnvVar: "JBP_CONFIG_OPEN_JDK_JRE",
			subdir:      "zulu-17.0.13",
			version:     "17.0.13",
			newJRE: func(ctx *common.Context) jres.JRE {
				return jres.NewZuluJRE(ctx)
			},
		},
		{
			description: "SapMachine",
			displayName: "SapMachine",
			envVar:      "JBP_CONFIG_SAP_MACHINE_JRE",
			otherEnvVar: "JBP_CONFIG_ZULU_JRE",
			subdir:      "sapmachine-17.0.13",
			version:     "17.0.13",
			newJRE: func(ctx *common.Context) jres.JRE {
				return jres.NewSapMachineJRE(ctx)
			},
		},
		{
			description: "IBM",
			displayName: "IBM JRE",
			envVar:      "JBP_CONFIG_IBM_JRE",
			otherEnvVar: "JBP_CONFIG_ORACLE_JRE",
			subdir:      "ibm-java-8.0",
			version:     "1.8.0_422",
			newJRE: func(ctx *common.Context) jres.JRE {
				return jres.NewIBMJRE(ctx)
			},
		},
		{
			description: "Oracle",
			displayName: "Oracle JRE",
			envVar:      "JBP_CONFIG_ORACLE_JRE",
			otherEnvVar: "JBP_CONFIG_GRAAL_VM_JRE",
			subdir:      "jdk-17.0.13",
			version:     "17.0.13",
			newJRE: func(ctx *common.Context) jres.JRE {
				return jres.NewOracleJRE(ctx)
			},
		},
		{
			description: "GraalVM",
			displayName: "GraalVM",
			envVar:      "JBP_CONFIG_GRAAL_VM_JRE",
			otherEnvVar: "JBP_CONFIG_SAP_MACHINE_JRE",
			subdir:      "graalvm-21.0.1",
			version:     "21.0.1",
			newJRE: func(ctx *common.Context) jres.JRE {
				return jres.NewGraalVMJRE(ctx)
			},
		},
	}

	for _, tc := range testCases {
		tc := tc

		Describe(tc.description, func() {
			var (
				ctx     *common.Context
				jre     jres.JRE
				cleanup func()
			)

			BeforeEach(func() {
				ctx, cleanup = makeTestContext()
				jre = tc.newJRE(ctx)
				clearJREEnvVars()
				DeferCleanup(cleanup)
				DeferCleanup(clearJREEnvVars)
				DeferCleanup(os.Unsetenv, "JAVA_HOME")
			})

			Describe("Name", func() {
				It("returns the expected display name", func() {
					Expect(jre.Name()).To(Equal(tc.displayName))
				})
			})

			Describe("Detect", func() {
				It("returns true when the correct environment variable is set", func() {
					Expect(os.Setenv(tc.envVar, "{jre: {version: 17.+}}")).To(Succeed())

					detected, err := jre.Detect()
					Expect(err).NotTo(HaveOccurred())
					Expect(detected).To(BeTrue())
				})

				It("returns false when no environment variable is set", func() {
					detected, err := jre.Detect()
					Expect(err).NotTo(HaveOccurred())
					Expect(detected).To(BeFalse())
				})

				It("returns false when a different JRE environment variable is set", func() {
					Expect(os.Setenv(tc.otherEnvVar, "{jre: {version: 17.+}}")).To(Succeed())

					detected, err := jre.Detect()
					Expect(err).NotTo(HaveOccurred())
					Expect(detected).To(BeFalse())
				})
			})

			Describe("Version", func() {
				It("returns empty before installation", func() {
					Expect(jre.Version()).To(BeEmpty())
				})
			})

			Describe("JavaHome", func() {
				It("returns empty before installation", func() {
					Expect(jre.JavaHome()).To(BeEmpty())
				})
			})

			Describe("Finalize", func() {
				It("sets JAVA_HOME using the JRE-specific directory prefix", func() {
					expectedJavaHome := createFakeJRE(ctx, tc.subdir, tc.version)

					Expect(jre.Finalize()).To(Succeed())
					Expect(os.Getenv("JAVA_HOME")).To(Equal(expectedJavaHome))
					Expect(jre.JavaHome()).To(Equal(expectedJavaHome))
				})
			})
		})
	}

	Describe("IBM", func() {
		var (
			ctx     *common.Context
			ibmJRE  jres.JRE
			cleanup func()
		)

		BeforeEach(func() {
			ctx, cleanup = makeTestContext()
			ibmJRE = jres.NewIBMJRE(ctx)
			clearJREEnvVars()
			DeferCleanup(cleanup)
			DeferCleanup(clearJREEnvVars)
			DeferCleanup(os.Unsetenv, "JAVA_HOME")
		})

		Describe("Finalize", func() {
			It("sets JAVA_HOME when the extracted directory is exactly jre", func() {
				expectedJavaHome := createFakeJRE(ctx, "jre", "1.8.0_422")

				Expect(ibmJRE.Finalize()).To(Succeed())
				Expect(os.Getenv("JAVA_HOME")).To(Equal(expectedJavaHome))
				Expect(ibmJRE.JavaHome()).To(Equal(expectedJavaHome))
			})
		})
	})
})

func makeTestContext() (*common.Context, func()) {
	buildDir, err := os.MkdirTemp("", "build")
	Expect(err).NotTo(HaveOccurred())

	depsDir, err := os.MkdirTemp("", "deps")
	Expect(err).NotTo(HaveOccurred())

	cacheDir, err := os.MkdirTemp("", "cache")
	Expect(err).NotTo(HaveOccurred())

	Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

	logger := libbuildpack.NewLogger(os.Stdout)
	manifest := &libbuildpack.Manifest{}
	installer := &libbuildpack.Installer{}
	stager := libbuildpack.NewStager([]string{buildDir, cacheDir, depsDir, "0"}, logger, manifest)
	command := &libbuildpack.Command{}

	ctx := &common.Context{
		Stager:    stager,
		Manifest:  manifest,
		Installer: installer,
		Log:       logger,
		Command:   command,
	}

	cleanup := func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(depsDir)
		os.RemoveAll(cacheDir)
	}

	return ctx, cleanup
}

func createFakeJRE(ctx *common.Context, subdir, version string) string {
	jreDir := filepath.Join(ctx.Stager.DepDir(), "jre")
	javaHome := jreDir
	if subdir != "" {
		javaHome = filepath.Join(jreDir, subdir)
	}

	Expect(os.MkdirAll(filepath.Join(javaHome, "bin"), 0755)).To(Succeed())
	Expect(os.WriteFile(filepath.Join(javaHome, "bin", "java"), []byte("#!/bin/sh\necho 'java version \""+version+"\"'\n"), 0755)).To(Succeed())
	Expect(os.WriteFile(filepath.Join(javaHome, "release"), []byte("JAVA_VERSION=\""+version+"\"\n"), 0644)).To(Succeed())

	return javaHome
}

func clearJREEnvVars() {
	for _, envVar := range []string{
		"JBP_CONFIG_OPENJDK",
		"JBP_CONFIG_OPEN_JDK_JRE",
		"JBP_CONFIG_ZULU",
		"JBP_CONFIG_ZULU_JRE",
		"JBP_CONFIG_SAPMACHINE",
		"JBP_CONFIG_SAP_MACHINE_JRE",
		"JBP_CONFIG_IBM",
		"JBP_CONFIG_IBM_JRE",
		"JBP_CONFIG_ORACLE",
		"JBP_CONFIG_ORACLE_JRE",
		"JBP_CONFIG_GRAALVM",
		"JBP_CONFIG_GRAAL_VM_JRE",
	} {
		os.Unsetenv(envVar)
	}
}
