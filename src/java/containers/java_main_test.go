package containers_test

import (
	"archive/zip"
	"bytes"
	"os"
	"path/filepath"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/containers"
	"github.com/cloudfoundry/libbuildpack"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

// createJar writes a JAR file at jarPath containing META-INF/MANIFEST.MF with the given content.
func createJar(jarPath, manifestContent string) error {
	buf := new(bytes.Buffer)
	w := zip.NewWriter(buf)
	f, err := w.Create("META-INF/MANIFEST.MF")
	if err != nil {
		return err
	}
	if _, err := f.Write([]byte(manifestContent)); err != nil {
		return err
	}
	if err := w.Close(); err != nil {
		return err
	}
	return os.WriteFile(jarPath, buf.Bytes(), 0644)
}

var _ = Describe("Java Main Container", func() {
	var (
		ctx       *common.Context
		container *containers.JavaMainContainer
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

		container = containers.NewJavaMainContainer(ctx)
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(depsDir)
		os.RemoveAll(cacheDir)
	})

	Describe("Detect", func() {
		Context("with JAR file containing Main-Class manifest", func() {
			BeforeEach(func() {
				Expect(createJar(
					filepath.Join(buildDir, "app.jar"),
					"Manifest-Version: 1.0\nMain-Class: com.example.Main\n",
				)).To(Succeed())
			})

			It("detects as Java Main", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Java Main"))
			})
		})

		Context("with JAR file without Main-Class manifest", func() {
			BeforeEach(func() {
				Expect(createJar(
					filepath.Join(buildDir, "lib.jar"),
					"Manifest-Version: 1.0\nCreated-By: test\n",
				)).To(Succeed())
			})

			It("does not detect via JAR alone", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with .class files", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "Main.class"), []byte{}, 0644)
			})

			It("detects as Java Main", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Java Main"))
			})
		})

		Context("with valid MANIFEST.MF", func() {
			BeforeEach(func() {
				metaInfDir := filepath.Join(buildDir, "META-INF")
				os.MkdirAll(metaInfDir, 0755)
				manifest := "Manifest-Version: 1.0\nMain-Class: com.example.Main\n"
				os.WriteFile(filepath.Join(metaInfDir, "MANIFEST.MF"), []byte(manifest), 0644)
			})

			It("detects main class", func() {
				jarFile := filepath.Join(buildDir, "app.jar")
				os.WriteFile(jarFile, []byte("fake"), 0644)

				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Java Main"))
			})
		})

		Context("with manifest without Main-Class", func() {
			BeforeEach(func() {
				metaInfDir := filepath.Join(buildDir, "META-INF")
				os.MkdirAll(metaInfDir, 0755)
				manifest := "Manifest-Version: 1.0\nCreated-By: test\n"
				os.WriteFile(filepath.Join(metaInfDir, "MANIFEST.MF"), []byte(manifest), 0644)
			})

			It("does not detect", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})
	})

	Describe("Release", func() {
		Context("with JAR file", func() {
			BeforeEach(func() {
				Expect(createJar(
					filepath.Join(buildDir, "app.jar"),
					"Manifest-Version: 1.0\nMain-Class: com.example.Main\n",
				)).To(Succeed())
				container.Detect()
			})

			It("uses java -jar", func() {
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(ContainSubstring("java"))
				Expect(cmd).To(ContainSubstring("-jar"))
				Expect(cmd).To(ContainSubstring("app.jar"))
			})

			It("does not require JAVA_MAIN_CLASS", func() {
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).NotTo(ContainSubstring("JAVA_MAIN_CLASS"))
			})
		})

		Context("with JAVA_MAIN_CLASS env variable", func() {
			BeforeEach(func() {
				os.Setenv("JAVA_MAIN_CLASS", "com.example.CustomMain")
				os.WriteFile(filepath.Join(buildDir, "Main.class"), []byte("fake"), 0644)
			})

			AfterEach(func() {
				os.Unsetenv("JAVA_MAIN_CLASS")
			})

			It("uses -cp with main class", func() {
				container.Detect()
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(ContainSubstring("-cp"))
				Expect(cmd).To(ContainSubstring("com.example.CustomMain"))
			})
		})

		Context("with JBP_CONFIG_JAVA_MAIN java_main_class overriding manifest Main-Class", func() {
			// Ruby parity: config[MAIN_CLASS_PROPERTY] takes precedence over manifest Main-Class
			// This is how PropertiesLauncher is used with Spring Boot exploded JARs
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_JAVA_MAIN", "{java_main_class: org.springframework.boot.loader.launch.PropertiesLauncher}")
				Expect(createJar(
					filepath.Join(buildDir, "app.jar"),
					"Manifest-Version: 1.0\nMain-Class: org.springframework.boot.loader.JarLauncher\n",
				)).To(Succeed())
			})

			AfterEach(func() {
				os.Unsetenv("JBP_CONFIG_JAVA_MAIN")
			})

			It("uses the configured java_main_class instead of the manifest Main-Class", func() {
				container.Detect()
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(ContainSubstring("org.springframework.boot.loader.launch.PropertiesLauncher"))
				Expect(cmd).NotTo(ContainSubstring("JarLauncher"))
			})

			It("uses classpath mode (not java -jar) so the overridden main class is actually invoked", func() {
				container.Detect()
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).NotTo(ContainSubstring("-jar"))
				Expect(cmd).To(ContainSubstring("-cp"))
			})
		})

		Context("with JBP_CONFIG_JAVA_MAIN java_main_class on app with no manifest Main-Class", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_JAVA_MAIN", "{java_main_class: com.example.CustomMain}")
				// App has no Main-Class in manifest — detection still works via JBP_CONFIG_JAVA_MAIN
				os.WriteFile(filepath.Join(buildDir, "app.jar"), []byte("fake"), 0644)
			})

			AfterEach(func() {
				os.Unsetenv("JBP_CONFIG_JAVA_MAIN")
			})

			It("detects as Java Main application", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Java Main"))
			})

			It("uses the configured main class", func() {
				container.Detect()
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(ContainSubstring("com.example.CustomMain"))
			})
		})

		Context("with JBP_CONFIG_JAVA_MAIN arguments", func() {
			AfterEach(func() {
				os.Unsetenv("JBP_CONFIG_JAVA_MAIN")
			})

			It("appends arguments after main class when using java_main_class", func() {
				os.Setenv("JBP_CONFIG_JAVA_MAIN", `{java_main_class: com.example.Main, arguments: "--server.port=$PORT"}`)
				container.Detect()
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(ContainSubstring("com.example.Main --server.port=$PORT"))
			})

			It("appends arguments after main class when using manifest Main-Class", func() {
				os.Setenv("JBP_CONFIG_JAVA_MAIN", `{arguments: "--foo=bar"}`)
				Expect(createJar(
					filepath.Join(buildDir, "app.jar"),
					"Manifest-Version: 1.0\nMain-Class: com.example.Main\n",
				)).To(Succeed())
				container.Detect()
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(ContainSubstring("--foo=bar"))
			})
		})

		Context("without main class or JAR", func() {
			It("returns error", func() {
				_, err := container.Release()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("no main class"))
			})
		})
	})

	Describe("buildClasspath", func() {
		Context("with JARs in root and lib/", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "app.jar"), []byte("fake"), 0644)
				os.WriteFile(filepath.Join(buildDir, "util.jar"), []byte("fake"), 0644)
				os.MkdirAll(filepath.Join(buildDir, "lib"), 0755)
				os.WriteFile(filepath.Join(buildDir, "lib", "dep1.jar"), []byte("fake"), 0644)
				os.WriteFile(filepath.Join(buildDir, "lib", "dep2.jar"), []byte("fake"), 0644)
			})

			It("includes all JARs in classpath", func() {
				os.Setenv("JAVA_MAIN_CLASS", "com.example.Main")
				defer os.Unsetenv("JAVA_MAIN_CLASS")

				os.WriteFile(filepath.Join(buildDir, "Main.class"), []byte("fake"), 0644)
				os.Remove(filepath.Join(buildDir, "app.jar"))
				os.Remove(filepath.Join(buildDir, "util.jar"))

				os.WriteFile(filepath.Join(buildDir, "lib", "dep1.jar"), []byte("fake"), 0644)
				os.WriteFile(filepath.Join(buildDir, "lib", "dep2.jar"), []byte("fake"), 0644)

				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(ContainSubstring("-cp"))
				Expect(cmd).To(ContainSubstring("com.example.Main"))
			})
		})

		Context("with no lib/ directory", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "Main.class"), []byte("fake"), 0644)
				os.Setenv("JAVA_MAIN_CLASS", "com.example.Main")
			})

			AfterEach(func() {
				os.Unsetenv("JAVA_MAIN_CLASS")
			})

			It("uses classpath with main class", func() {
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(ContainSubstring("-cp"))
				Expect(cmd).To(ContainSubstring("com.example.Main"))
				Expect(cmd).NotTo(ContainSubstring("lib/"))
			})
		})

		Context("with empty directory", func() {
			BeforeEach(func() {
				os.Setenv("JAVA_MAIN_CLASS", "com.example.Main")
			})

			AfterEach(func() {
				os.Unsetenv("JAVA_MAIN_CLASS")
			})

			It("returns classpath with current directory", func() {
				cmd, err := container.Release()
				Expect(err).NotTo(HaveOccurred())
				Expect(cmd).To(ContainSubstring("."))
			})
		})
	})

	Describe("Finalize", func() {
		Context("with JARs in root and lib/", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "app.jar"), []byte("fake"), 0644)
				os.WriteFile(filepath.Join(buildDir, "util.jar"), []byte("fake"), 0644)
				os.MkdirAll(filepath.Join(buildDir, "lib"), 0755)
				os.WriteFile(filepath.Join(buildDir, "lib", "dep1.jar"), []byte("fake"), 0644)
				os.WriteFile(filepath.Join(buildDir, "lib", "dep2.jar"), []byte("fake"), 0644)
			})

			It("builds correct classpath", func() {
				os.WriteFile(filepath.Join(buildDir, "Main.class"), []byte("fake"), 0644)
				container.Detect()

				err := container.Finalize()
				Expect(err).NotTo(HaveOccurred())
			})
		})

		Context("with only lib/ directory", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "lib"), 0755)
				os.WriteFile(filepath.Join(buildDir, "lib", "dep1.jar"), []byte("fake"), 0644)
				os.WriteFile(filepath.Join(buildDir, "Main.class"), []byte("fake"), 0644)
			})

			It("includes lib JARs in classpath", func() {
				container.Detect()
				err := container.Finalize()
				Expect(err).NotTo(HaveOccurred())
			})
		})

		Context("with Spring Boot launcher in JBP_CONFIG_JAVA_MAIN", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_JAVA_MAIN", `{java_main_class: "org.springframework.boot.loader.launch.PropertiesLauncher"}`)
				os.WriteFile(filepath.Join(buildDir, "app.jar"), []byte("fake"), 0644)
			})

			AfterEach(func() {
				os.Unsetenv("JBP_CONFIG_JAVA_MAIN")
			})

			It("writes SERVER_PORT=$PORT to profile.d for Ruby parity", func() {
				container.Detect()
				err := container.Finalize()
				Expect(err).NotTo(HaveOccurred())

				profileScript := filepath.Join(depsDir, "0", "profile.d", "java_main.sh")
				data, err := os.ReadFile(profileScript)
				Expect(err).NotTo(HaveOccurred())
				Expect(string(data)).To(ContainSubstring("export SERVER_PORT=$PORT\n"))
			})
		})

		Context("with non-Spring-Boot main class", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "Main.class"), []byte("fake"), 0644)
			})

			It("does not write SERVER_PORT to profile.d", func() {
				container.Detect()
				err := container.Finalize()
				Expect(err).NotTo(HaveOccurred())

				profileScript := filepath.Join(depsDir, "0", "profile.d", "java_main.sh")
				data, err := os.ReadFile(profileScript)
				Expect(err).NotTo(HaveOccurred())
				Expect(string(data)).NotTo(ContainSubstring("SERVER_PORT"))
			})
		})

	})
})
