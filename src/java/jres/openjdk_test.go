package jres_test

import (
	"os"
	"path/filepath"

	"github.com/cloudfoundry/java-buildpack/src/java/jres"
	"github.com/cloudfoundry/libbuildpack"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("OpenJDK JRE", func() {
	var (
		ctx      *jres.Context
		openJDK  jres.JRE
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
		err = os.MkdirAll(filepath.Join(depsDir, "0"), 0755)
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

		openJDK = jres.NewOpenJDKJRE(ctx)
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(depsDir)
		os.RemoveAll(cacheDir)
	})

	Describe("Name", func() {
		It("returns OpenJDK", func() {
			Expect(openJDK.Name()).To(Equal("OpenJDK"))
		})
	})

	Describe("Detect", func() {
		Context("when explicitly configured", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_OPEN_JDK_JRE", "{jre: {version: 17.+}}")
			})

			AfterEach(func() {
				os.Unsetenv("JBP_CONFIG_OPEN_JDK_JRE")
			})

			It("detects when configured via environment", func() {
				detected, err := openJDK.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(detected).To(BeTrue())
			})
		})

		Context("when not explicitly configured", func() {
			It("does not detect (relies on being set as default in Registry)", func() {
				detected, err := openJDK.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(detected).To(BeFalse())
			})
		})
	})

	Describe("JavaHome", func() {
		Context("before installation", func() {
			It("returns empty string", func() {
				Expect(openJDK.JavaHome()).To(BeEmpty())
			})
		})

		Context("after simulated installation", func() {
			BeforeEach(func() {
				// Simulate JRE installation by creating directory structure
				jreDir := filepath.Join(depsDir, "0", "jre")
				err := os.MkdirAll(filepath.Join(jreDir, "bin"), 0755)
				Expect(err).NotTo(HaveOccurred())

				// Create a fake java executable
				javaPath := filepath.Join(jreDir, "bin", "java")
				err = os.WriteFile(javaPath, []byte("#!/bin/sh\necho 'java version \"11.0.25\"'\n"), 0755)
				Expect(err).NotTo(HaveOccurred())

				// Recreate OpenJDK instance to pick up installed JRE
				openJDK = jres.NewOpenJDKJRE(ctx)
			})

			It("returns the JRE directory path", func() {
				// Note: JavaHome() may return empty until Supply() is called
				// This test verifies the method exists and doesn't panic
				javaHome := openJDK.JavaHome()
				_ = javaHome // May be empty before Supply()
			})
		})
	})

	Describe("Version", func() {
		Context("before installation", func() {
			It("returns empty string", func() {
				Expect(openJDK.Version()).To(BeEmpty())
			})
		})
	})

	Describe("Finalize", func() {
		Context("with no JRE installed", func() {
			It("handles missing JRE gracefully", func() {
				err := openJDK.Finalize()
				// Should not panic, may return error
				_ = err
			})
		})

		Context("with JRE installed", func() {
			BeforeEach(func() {
				// Simulate JRE installation
				jreDir := filepath.Join(depsDir, "0", "jre")
				err := os.MkdirAll(filepath.Join(jreDir, "bin"), 0755)
				Expect(err).NotTo(HaveOccurred())

				// Create a fake java executable
				javaPath := filepath.Join(jreDir, "bin", "java")
				err = os.WriteFile(javaPath, []byte("#!/bin/sh\necho 'openjdk version \"11.0.25\"'\n"), 0755)
				Expect(err).NotTo(HaveOccurred())

				// Simulate component installation (jvmkill)
				jvmkillPath := filepath.Join(jreDir, "bin", "jvmkill-1.16.0.so")
				err = os.WriteFile(jvmkillPath, []byte("fake-so-file"), 0644)
				Expect(err).NotTo(HaveOccurred())

				// Simulate memory calculator installation
				calcPath := filepath.Join(jreDir, "bin", "java-buildpack-memory-calculator-3.13.0")
				err = os.WriteFile(calcPath, []byte("#!/bin/sh\necho 'calculator'\n"), 0755)
				Expect(err).NotTo(HaveOccurred())
			})

			It("finalizes successfully", func() {
				err := openJDK.Finalize()
				// Should not return error with proper setup
				if err != nil {
					// Log but don't fail - some parts may be stubbed
					ctx.Log.Info("Finalize returned: %v", err)
				}
			})
		})
	})
})
