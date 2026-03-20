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

var _ = Describe("Play Container", func() {
	var (
		ctx       *common.Context
		container *containers.PlayContainer
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

		container = containers.NewPlayContainer(ctx)
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(depsDir)
		os.RemoveAll(cacheDir)
	})

	Describe("Detect", func() {
		Context("with Play 2.0 dist application (application-root/start)", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "application-root"), 0755)
				os.WriteFile(filepath.Join(buildDir, "application-root", "start"), []byte("#!/bin/sh"), 0755)
				os.MkdirAll(filepath.Join(buildDir, "application-root", "lib"), 0755)
				os.WriteFile(filepath.Join(buildDir, "application-root", "lib", "play.play_2.9.1-2.0.jar"), []byte("fake"), 0644)
			})

			It("detects as Play", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Play"))
			})
		})

		Context("with Play 2.1 dist application (application-root/start)", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "application-root"), 0755)
				os.WriteFile(filepath.Join(buildDir, "application-root", "start"), []byte("#!/bin/sh"), 0755)
				os.MkdirAll(filepath.Join(buildDir, "application-root", "lib"), 0755)
				os.WriteFile(filepath.Join(buildDir, "application-root", "lib", "play.play_2.10-2.1.4.jar"), []byte("fake"), 0644)
			})

			It("detects as Play", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Play"))
			})
		})

		Context("with Play 2.1 staged application (staged directory)", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "staged"), 0755)
				os.WriteFile(filepath.Join(buildDir, "staged", "play_2.10-2.1.4.jar"), []byte("fake"), 0644)
			})

			It("detects as Play", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Play"))
			})
		})

		Context("with Play 2.2 dist application (typesafe path)", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "application-root", "bin"), 0755)
				os.WriteFile(filepath.Join(buildDir, "application-root", "bin", "myapp"), []byte("#!/bin/sh"), 0755)
				os.MkdirAll(filepath.Join(buildDir, "application-root", "lib"), 0755)
				os.WriteFile(filepath.Join(buildDir, "application-root", "lib", "com.typesafe.play.play_2.10-2.2.0.jar"), []byte("fake"), 0644)
			})

			It("detects as Play", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Play"))
			})
		})

		Context("with Play 2.2 staged application (lib directory)", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "lib"), 0755)
				os.WriteFile(filepath.Join(buildDir, "lib", "com.typesafe.play.play_2.10-2.2.0.jar"), []byte("fake"), 0644)
			})

			It("detects as Play", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Play"))
			})
		})

		Context("with non-Play application", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "app.jar"), []byte("fake"), 0644)
			})

			It("does not detect as Play", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with only start script but no Play JAR", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "application-root"), 0755)
				os.WriteFile(filepath.Join(buildDir, "application-root", "start"), []byte("#!/bin/sh"), 0755)
			})

			It("does not detect as Play", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})
	})

	Describe("Release", func() {
		Context("with Play 2.0 dist application", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "application-root"), 0755)
				os.WriteFile(filepath.Join(buildDir, "application-root", "start"), []byte("#!/bin/sh"), 0755)
				os.MkdirAll(filepath.Join(buildDir, "application-root", "lib"), 0755)
				os.WriteFile(filepath.Join(buildDir, "application-root", "lib", "play.play_2.9.1-2.0.jar"), []byte("fake"), 0644)
				_, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
			})

			It("returns correct start command", func() {
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(Equal("$HOME/application-root/start"))
			})
		})

		Context("with Play 2.1 staged application", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "staged"), 0755)
				os.WriteFile(filepath.Join(buildDir, "staged", "play_2.10-2.1.4.jar"), []byte("fake"), 0644)
				_, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
			})

			It("returns correct java command", func() {
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(ContainSubstring("java $JAVA_OPTS -cp"))
				Expect(cmd).To(ContainSubstring("play.core.server.NettyServer $HOME"))
			})
		})

		Context("with Play 2.2 staged application", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "lib"), 0755)
				os.WriteFile(filepath.Join(buildDir, "lib", "com.typesafe.play.play_2.10-2.2.0.jar"), []byte("fake"), 0644)
				_, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
			})

			It("returns correct java command", func() {
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(ContainSubstring("java $JAVA_OPTS -cp"))
				Expect(cmd).To(ContainSubstring("play.core.server.NettyServer $HOME"))
			})
		})

		Context("when not detected", func() {
			It("returns error", func() {
				_, err := container.Release()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no Play application detected"))
			})
		})
	})

	Describe("Finalize", func() {
		Context("with detected Play application", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "application-root"), 0755)
				os.WriteFile(filepath.Join(buildDir, "application-root", "start"), []byte("#!/bin/sh"), 0755)
				os.MkdirAll(filepath.Join(buildDir, "application-root", "lib"), 0755)
				os.WriteFile(filepath.Join(buildDir, "application-root", "lib", "play.play_2.9.1-2.0.jar"), []byte("fake"), 0644)
				_, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
			})

			It("finalizes successfully", func() {
				err := container.Finalize()
				Expect(err).NotTo(HaveOccurred())
			})
		})
	})
})
