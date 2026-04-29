package jres_test

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/jres"
	"github.com/cloudfoundry/libbuildpack"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

// These tests document and demonstrate known regressions introduced by the
// migration from the Ruby buildpack (memory calculator v3) to the Go buildpack
// (memory calculator v4). Each test is expected to FAIL until the issue is fixed.
//
// Tracked in: https://github.com/cloudfoundry/java-buildpack/issues/1257

var _ = Describe("Memory Calculator Issues", func() {
	var (
		buildDir string
		depsDir  string
		cacheDir string
		ctx      *common.Context
		jreDir   string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "mc-issues-build")
		Expect(err).NotTo(HaveOccurred())

		depsDir, err = os.MkdirTemp("", "mc-issues-deps")
		Expect(err).NotTo(HaveOccurred())

		cacheDir, err = os.MkdirTemp("", "mc-issues-cache")
		Expect(err).NotTo(HaveOccurred())

		Expect(os.MkdirAll(depsDir+"/0", 0755)).To(Succeed())

		logBuffer := &bytes.Buffer{}
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

		jreDir = filepath.Join(depsDir, "0", "jre")
		Expect(os.MkdirAll(filepath.Join(jreDir, "bin"), 0755)).To(Succeed())
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(depsDir)
		os.RemoveAll(cacheDir)
	})

	// fakeBinary writes a placeholder file that detectInstalledCalculator() will find.
	// Required for tests that go through Finalize() or GetCalculatorCommand(),
	// since both return early if no calculator binary is detected.
	fakeBinary := func(version string) {
		name := fmt.Sprintf("java-buildpack-memory-calculator-%s", version)
		path := filepath.Join(jreDir, "bin", name)
		Expect(os.WriteFile(path, []byte("#!/bin/sh\n"), 0755)).To(Succeed())
	}

	// readGeneratedScript returns the content of the generated memory_calculator.sh.
	readGeneratedScript := func() string {
		path := filepath.Join(depsDir, "0", "bin", "memory_calculator.sh")
		data, err := os.ReadFile(path)
		Expect(err).NotTo(HaveOccurred())
		return string(data)
	}

	// -------------------------------------------------------------------------
	// https://github.com/cloudfoundry/java-buildpack/issues/1257
	// LoadConfig() appears not to be called — MEMORY_CALCULATOR_* env vars silently ignored
	//
	// LoadConfig() reads MEMORY_CALCULATOR_STACK_THREADS and MEMORY_CALCULATOR_HEADROOM
	// but appears not to be invoked during Supply() or Finalize(). Teams cannot
	// tune stack_threads or headroom to work around the memory regression.
	//
	// Expected fix: call LoadConfig() at the start of Supply() (before countClasses()),
	// so both stack_threads and headroom overrides are in effect before the script
	// is built in Finalize().
	// -------------------------------------------------------------------------
	Describe("#1257: LoadConfig() never called, MEMORY_CALCULATOR_* env vars silently ignored", func() {
		It("MEMORY_CALCULATOR_STACK_THREADS env var reduces thread count in generated script", func() {
			DeferCleanup(os.Unsetenv, "MEMORY_CALCULATOR_STACK_THREADS")
			Expect(os.Setenv("MEMORY_CALCULATOR_STACK_THREADS", "50")).To(Succeed())

			fakeBinary("4.2.0")
			mc := jres.NewMemoryCalculator(ctx, jreDir, "17.0.9", 17)
			Expect(mc.Finalize()).To(Succeed())

			script := readGeneratedScript()

			// This assertion FAILS until LoadConfig() is called at the start of Supply():
			// currently the script will contain --thread-count=250 (the default).
			Expect(script).To(ContainSubstring("--thread-count=50"),
				"expected --thread-count=50 from MEMORY_CALCULATOR_STACK_THREADS env var, "+
					"but LoadConfig() appears not to be called so the override is silently ignored.\nScript:\n%s", script)
		})

		It("MEMORY_CALCULATOR_HEADROOM env var applies headroom in generated script", func() {
			DeferCleanup(os.Unsetenv, "MEMORY_CALCULATOR_HEADROOM")
			Expect(os.Setenv("MEMORY_CALCULATOR_HEADROOM", "5")).To(Succeed())

			fakeBinary("4.2.0")
			mc := jres.NewMemoryCalculator(ctx, jreDir, "17.0.9", 17)
			Expect(mc.Finalize()).To(Succeed())

			script := readGeneratedScript()

			// This assertion FAILS until LoadConfig() is called at the start of Supply():
			// currently no --head-room flag appears because headroom defaults to 0.
			Expect(script).To(ContainSubstring("--head-room=5"),
				"expected --head-room=5 from MEMORY_CALCULATOR_HEADROOM env var, "+
					"but LoadConfig() appears not to be called.\nScript:\n%s", script)
		})
	})

	// -------------------------------------------------------------------------
	// https://github.com/cloudfoundry/java-buildpack/issues/1257
	// JBP_CONFIG_OPEN_JDK_JRE env var is not parsed
	//
	// The CF convention for tuning the memory calculator is:
	//   JBP_CONFIG_OPEN_JDK_JRE: '{ memory_calculator: { stack_threads: 50 } }'
	//
	// Two bugs appear to prevent this from working:
	//   a) LoadConfig() appears not to be called during Supply() or Finalize()
	//   b) LoadConfig() reads MEMORY_CALCULATOR_STACK_THREADS instead of
	//      parsing JBP_CONFIG_OPEN_JDK_JRE
	//
	// Note: class_count override must be loaded before countClasses() in Supply();
	// stack_threads must be loaded before buildCalculatorCommand() in Finalize().
	// Therefore LoadConfig() should be called at the start of Supply().
	//
	// Reducing stack_threads from 250 → 50 saves 200M of stack, which is the
	// primary mitigation available to teams hitting the 750M regression.
	// -------------------------------------------------------------------------
	Describe("#1257: JBP_CONFIG_OPEN_JDK_JRE is not parsed, stack_threads override silently ignored", func() {
		It("stack_threads set via JBP_CONFIG_OPEN_JDK_JRE is reflected in generated script", func() {
			DeferCleanup(os.Unsetenv, "JBP_CONFIG_OPEN_JDK_JRE")
			Expect(os.Setenv("JBP_CONFIG_OPEN_JDK_JRE",
				"{ memory_calculator: { stack_threads: 50 } }")).To(Succeed())

			fakeBinary("4.2.0")
			mc := jres.NewMemoryCalculator(ctx, jreDir, "17.0.9", 17)
			Expect(mc.Finalize()).To(Succeed())

			script := readGeneratedScript()

			// This assertion FAILS until JBP_CONFIG_OPEN_JDK_JRE is parsed:
			// currently the script will contain --thread-count=250 (the default).
			// Fix: parse JBP_CONFIG_OPEN_JDK_JRE in LoadConfig() and call it at
			// the start of Supply(). With 50 threads: stack = 50M instead of 250M
			// → saves 200M, making 750M containers viable again.
			Expect(script).To(ContainSubstring("--thread-count=50"),
				"expected --thread-count=50 from JBP_CONFIG_OPEN_JDK_JRE but got default 250.\n"+
					"Fix: parse JBP_CONFIG_OPEN_JDK_JRE in LoadConfig() and call it at start of Supply().\nScript:\n%s",
				script)
		})

		It("class_count set via JBP_CONFIG_OPEN_JDK_JRE overrides calculated count", func() {
			DeferCleanup(os.Unsetenv, "JBP_CONFIG_OPEN_JDK_JRE")
			Expect(os.Setenv("JBP_CONFIG_OPEN_JDK_JRE",
				"{ memory_calculator: { class_count: 3500 } }")).To(Succeed())

			fakeBinary("4.2.0")
			mc := jres.NewMemoryCalculator(ctx, jreDir, "17.0.9", 17)
			Expect(mc.Finalize()).To(Succeed())

			script := readGeneratedScript()

			// This assertion FAILS until JBP_CONFIG_OPEN_JDK_JRE is parsed.
			// class_count must be loaded before countClasses() runs in Supply().
			// class_count=3500 keeps metaspace at ~34M instead of ~233M.
			Expect(script).To(ContainSubstring("--loaded-class-count=3500"),
				"expected --loaded-class-count=3500 from JBP_CONFIG_OPEN_JDK_JRE.\nScript:\n%s",
				script)
		})
	})
})
