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

var _ = Describe("Dist ZIP Container", func() {
	var (
		ctx       *common.Context
		container *containers.DistZipContainer
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

		container = containers.NewDistZipContainer(ctx)
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(depsDir)
		os.RemoveAll(cacheDir)
	})

	Describe("Detect", func() {
		Context("with bin/ and lib/ directories and startup script", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "bin"), 0755)
				os.MkdirAll(filepath.Join(buildDir, "lib"), 0755)
				os.WriteFile(filepath.Join(buildDir, "bin", "start"), []byte("#!/bin/sh"), 0755)
			})

			It("detects as Dist ZIP", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Dist ZIP"))
			})
		})

		Context("with bin/ and lib/ but no startup script", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "bin"), 0755)
				os.MkdirAll(filepath.Join(buildDir, "lib"), 0755)
			})

			It("does not detect", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with only bin/ directory", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "bin"), 0755)
				os.WriteFile(filepath.Join(buildDir, "bin", "app"), []byte("#!/bin/sh"), 0755)
			})

			It("does not detect (needs lib/ too)", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with bin/ and lib/ inside an immediate subdirectory", func() {
			BeforeEach(func() {
				nested := filepath.Join(buildDir, "my-app-1.0")
				os.MkdirAll(filepath.Join(nested, "bin"), 0755)
				os.MkdirAll(filepath.Join(nested, "lib"), 0755)
				os.WriteFile(filepath.Join(nested, "bin", "launcher"), []byte("#!/bin/sh"), 0755)
			})

			It("detects as Dist ZIP", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Dist ZIP"))
			})
		})

		Context("with multiple bin/lib structures", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "bin"), 0755)
				os.MkdirAll(filepath.Join(buildDir, "lib"), 0755)
				os.WriteFile(filepath.Join(buildDir, "bin", "start"), []byte("#!/bin/sh"), 0755)

				nested := filepath.Join(buildDir, "second")
				os.MkdirAll(filepath.Join(nested, "bin"), 0755)
				os.MkdirAll(filepath.Join(nested, "lib"), 0755)
				os.WriteFile(filepath.Join(nested, "bin", "launcher"), []byte("#!/bin/sh"), 0755)
			})

			It("does not detect", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})
	})

	Describe("Release", func() {
		Context("with start script in root structure", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "bin"), 0755)
				os.MkdirAll(filepath.Join(buildDir, "lib"), 0755)
				os.WriteFile(filepath.Join(buildDir, "bin", "myapp"), []byte("#!/bin/sh"), 0755)
				container.Detect()
			})

			It("uses absolute path with $HOME prefix", func() {
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(Equal("$HOME/bin/myapp"))
			})
		})

		Context("with start script in application-root structure", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "application-root", "bin"), 0755)
				os.MkdirAll(filepath.Join(buildDir, "application-root", "lib"), 0755)
				os.WriteFile(filepath.Join(buildDir, "application-root", "bin", "launcher"), []byte("#!/bin/sh"), 0755)
				container.Detect()
			})

			It("uses absolute path with $HOME prefix", func() {
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(Equal("$HOME/application-root/bin/launcher"))
			})
		})

		Context("with start script in immediate subdirectory", func() {
			BeforeEach(func() {
				nested := filepath.Join(buildDir, "custom")
				os.MkdirAll(filepath.Join(nested, "bin"), 0755)
				os.MkdirAll(filepath.Join(nested, "lib"), 0755)
				os.WriteFile(filepath.Join(nested, "bin", "run"), []byte("#!/bin/sh"), 0755)
				container.Detect()
			})

			It("uses absolute path with $HOME prefix", func() {
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(Equal("$HOME/custom/bin/run"))
			})
		})

		Context("with no start script detected", func() {
			It("returns error", func() {
				_, err := container.Release()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no start script found"))
			})
		})
	})

	Describe("Finalize", func() {
		BeforeEach(func() {
			os.MkdirAll(filepath.Join(buildDir, "bin"), 0755)
			os.MkdirAll(filepath.Join(buildDir, "lib"), 0755)
			os.WriteFile(filepath.Join(buildDir, "bin", "app"), []byte("#!/bin/sh"), 0755)
			container.Detect()
		})

		It("finalizes successfully", func() {
			err := container.Finalize()
			Expect(err).NotTo(HaveOccurred())
		})

		It("writes profile.d script that exports JAVA_OPTS with $TMPDIR", func() {
			Expect(container.Finalize()).To(Succeed())
			scriptPath := filepath.Join(depsDir, "0", "profile.d", "dist_zip_java_opts.sh")
			Expect(scriptPath).To(BeAnExistingFile())
			content, err := os.ReadFile(scriptPath)
			Expect(err).NotTo(HaveOccurred())
			Expect(string(content)).To(ContainSubstring("export JAVA_OPTS="))
			Expect(string(content)).To(ContainSubstring("$TMPDIR"))
		})
	})
})
