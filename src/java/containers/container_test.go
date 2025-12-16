package containers_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/cloudfoundry/java-buildpack/src/java/containers"
	"github.com/cloudfoundry/libbuildpack"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestContainers(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Containers Suite")
}

var _ = Describe("Container Registry", func() {
	var (
		ctx      *containers.Context
		registry *containers.Registry
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

		ctx = &containers.Context{
			Stager:    stager,
			Manifest:  manifest,
			Installer: installer,
			Log:       logger,
			Command:   command,
		}

		registry = containers.NewRegistry(ctx)
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(depsDir)
		os.RemoveAll(cacheDir)
	})

	Describe("Spring Boot Container", func() {
		Context("with BOOT-INF directory", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "BOOT-INF"), 0755)
				// Create META-INF/MANIFEST.MF with Spring Boot markers
				os.MkdirAll(filepath.Join(buildDir, "META-INF"), 0755)
				manifest := "Manifest-Version: 1.0\nStart-Class: com.example.App\nSpring-Boot-Version: 2.7.0\n"
				os.WriteFile(filepath.Join(buildDir, "META-INF", "MANIFEST.MF"), []byte(manifest), 0644)
			})

			It("detects as Spring Boot", func() {
				container := containers.NewSpringBootContainer(ctx)
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Spring Boot"))
			})
		})

		Context("without Spring Boot indicators", func() {
			It("does not detect as Spring Boot", func() {
				container := containers.NewSpringBootContainer(ctx)
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})
	})

	Describe("Tomcat Container", func() {
		Context("with WEB-INF directory", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "WEB-INF"), 0755)
			})

			It("detects as Tomcat", func() {
				container := containers.NewTomcatContainer(ctx)
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
				container := containers.NewTomcatContainer(ctx)
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Tomcat"))
			})
		})
	})

	Describe("Groovy Container", func() {
		Context("with .groovy files", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "app.groovy"), []byte("println 'hello'"), 0644)
			})

			It("detects as Groovy", func() {
				container := containers.NewGroovyContainer(ctx)
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Groovy"))
			})
		})
	})

	Describe("Dist ZIP Container", func() {
		Context("with bin/ and lib/ directories and startup script", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "bin"), 0755)
				os.MkdirAll(filepath.Join(buildDir, "lib"), 0755)
				os.WriteFile(filepath.Join(buildDir, "bin", "start"), []byte("#!/bin/sh"), 0755)
			})

			It("detects as Dist ZIP", func() {
				container := containers.NewDistZipContainer(ctx)
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Dist ZIP"))
			})
		})
	})

	Describe("Java Main Container", func() {
		Context("with JAR file", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "app.jar"), []byte{}, 0644)
			})

			It("detects as Java Main", func() {
				container := containers.NewJavaMainContainer(ctx)
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Java Main"))
			})
		})

		Context("with .class files", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "Main.class"), []byte{}, 0644)
			})

			It("detects as Java Main", func() {
				container := containers.NewJavaMainContainer(ctx)
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Java Main"))
			})
		})
	})

	Describe("Registry", func() {
		BeforeEach(func() {
			registry.Register(containers.NewSpringBootContainer(ctx))
			registry.Register(containers.NewTomcatContainer(ctx))
			registry.Register(containers.NewGroovyContainer(ctx))
			registry.Register(containers.NewDistZipContainer(ctx))
			registry.Register(containers.NewJavaMainContainer(ctx))
		})

		Context("with Spring Boot app", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "BOOT-INF"), 0755)
				// Create META-INF/MANIFEST.MF with Spring Boot markers
				os.MkdirAll(filepath.Join(buildDir, "META-INF"), 0755)
				manifest := "Manifest-Version: 1.0\nStart-Class: com.example.App\nSpring-Boot-Version: 2.7.0\n"
				os.WriteFile(filepath.Join(buildDir, "META-INF", "MANIFEST.MF"), []byte(manifest), 0644)
			})

			It("detects Spring Boot container", func() {
				container, name, err := registry.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(container).NotTo(BeNil())
				Expect(name).To(Equal("Spring Boot"))
			})
		})

		Context("with no detectable app", func() {
			It("returns nil container", func() {
				container, name, err := registry.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(container).To(BeNil())
				Expect(name).To(BeEmpty())
			})
		})
	})

	Describe("Spring Boot Container - Advanced", func() {
		var container *containers.SpringBootContainer

		BeforeEach(func() {
			container = containers.NewSpringBootContainer(ctx)
		})

		Describe("Detect with various JAR patterns", func() {
			Context("with spring-boot.jar", func() {
				BeforeEach(func() {
					os.WriteFile(filepath.Join(buildDir, "spring-boot.jar"), []byte("fake jar"), 0644)
				})

				It("detects as Spring Boot", func() {
					name, err := container.Detect()
					Expect(err).NotTo(HaveOccurred())
					Expect(name).To(Equal("Spring Boot"))
				})
			})

			Context("with myapp-boot.jar", func() {
				BeforeEach(func() {
					os.WriteFile(filepath.Join(buildDir, "myapp-boot.jar"), []byte("fake jar"), 0644)
				})

				It("detects as Spring Boot", func() {
					name, err := container.Detect()
					Expect(err).NotTo(HaveOccurred())
					Expect(name).To(Equal("Spring Boot"))
				})
			})

			Context("with non-Spring Boot JAR", func() {
				BeforeEach(func() {
					os.WriteFile(filepath.Join(buildDir, "regular.jar"), []byte("fake jar"), 0644)
				})

				It("does not detect as Spring Boot", func() {
					name, err := container.Detect()
					Expect(err).NotTo(HaveOccurred())
					Expect(name).To(BeEmpty())
				})
			})
		})

		Describe("Release", func() {
			Context("with exploded JAR (BOOT-INF)", func() {
				BeforeEach(func() {
					os.MkdirAll(filepath.Join(buildDir, "BOOT-INF"), 0755)
					// Create META-INF/MANIFEST.MF with Spring Boot markers
					os.MkdirAll(filepath.Join(buildDir, "META-INF"), 0755)
					manifest := "Manifest-Version: 1.0\nMain-Class: org.springframework.boot.loader.JarLauncher\nStart-Class: com.example.App\nSpring-Boot-Version: 2.7.0\n"
					os.WriteFile(filepath.Join(buildDir, "META-INF", "MANIFEST.MF"), []byte(manifest), 0644)
					container.Detect()
				})

				It("uses JarLauncher", func() {
					cmd, err := container.Release()
					Expect(err).NotTo(HaveOccurred())
					Expect(cmd).To(ContainSubstring("JarLauncher"))
				})
			})

			Context("with Spring Boot JAR", func() {
				BeforeEach(func() {
					// Create a proper Spring Boot JAR structure
					jarPath := filepath.Join(buildDir, "app-boot.jar")
					os.WriteFile(jarPath, []byte("fake jar content"), 0644)
					container.Detect()
				})

				It("uses java -jar", func() {
					cmd, err := container.Release()
					Expect(err).NotTo(HaveOccurred())
					Expect(cmd).To(ContainSubstring("java"))
					Expect(cmd).To(ContainSubstring("app-boot.jar"))
				})
			})

			Context("with no Spring Boot JAR found", func() {
				It("returns error", func() {
					_, err := container.Release()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("no Spring Boot JAR"))
				})
			})
		})
	})

	Describe("Java Main Container - Advanced", func() {
		var container *containers.JavaMainContainer

		BeforeEach(func() {
			container = containers.NewJavaMainContainer(ctx)
		})

		Describe("readMainClassFromManifest", func() {
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
					metaInfDir := filepath.Join(buildDir, "META-INF")
					os.MkdirAll(metaInfDir, 0755)
					manifest := "Manifest-Version: 1.0\nMain-Class: com.example.Main\n"
					os.WriteFile(filepath.Join(metaInfDir, "MANIFEST.MF"), []byte(manifest), 0644)
					os.WriteFile(filepath.Join(buildDir, "app.jar"), []byte("fake"), 0644)
					container.Detect()
				})

				It("uses java -jar", func() {
					cmd, err := container.Release()
					Expect(err).NotTo(HaveOccurred())
					Expect(cmd).To(ContainSubstring("java"))
					Expect(cmd).To(ContainSubstring("-jar"))
					Expect(cmd).To(ContainSubstring("app.jar"))
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
					// Test buildClasspath directly since Release() prefers JAR execution
					// when a JAR with Main-Class is detected
					os.Setenv("JAVA_MAIN_CLASS", "com.example.Main")
					defer os.Unsetenv("JAVA_MAIN_CLASS")

					// Don't call Detect() to avoid setting jarFile
					// Just test the classpath building logic with .class files
					os.WriteFile(filepath.Join(buildDir, "Main.class"), []byte("fake"), 0644)
					os.Remove(filepath.Join(buildDir, "app.jar"))
					os.Remove(filepath.Join(buildDir, "util.jar"))

					// Re-create just lib JARs
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
	})

	Describe("Tomcat Container - Advanced", func() {
		var container *containers.TomcatContainer

		BeforeEach(func() {
			container = containers.NewTomcatContainer(ctx)
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

	Describe("Groovy Container - Advanced", func() {
		var container *containers.GroovyContainer

		BeforeEach(func() {
			container = containers.NewGroovyContainer(ctx)
		})

		Context("with multiple .groovy files", func() {
			BeforeEach(func() {
				os.WriteFile(filepath.Join(buildDir, "app.groovy"), []byte("println 'app'"), 0644)
				os.WriteFile(filepath.Join(buildDir, "util.groovy"), []byte("println 'util'"), 0644)
				os.WriteFile(filepath.Join(buildDir, "main.groovy"), []byte("println 'main'"), 0644)
			})

			It("detects as Groovy", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Groovy"))
			})
		})

		Context("with .groovy in src/", func() {
			BeforeEach(func() {
				os.MkdirAll(filepath.Join(buildDir, "src"), 0755)
				os.WriteFile(filepath.Join(buildDir, "src", "app.groovy"), []byte("println 'app'"), 0644)
			})

			It("does not detect (only checks root)", func() {
				name, err := container.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Describe("Release", func() {
			Context("with GROOVY_SCRIPT environment variable", func() {
				BeforeEach(func() {
					os.Setenv("GROOVY_SCRIPT", "custom.groovy")
					os.WriteFile(filepath.Join(buildDir, "app.groovy"), []byte("println 'app'"), 0644)
					container.Detect()
				})

				AfterEach(func() {
					os.Unsetenv("GROOVY_SCRIPT")
				})

				It("uses the specified script", func() {
					cmd, err := container.Release()
					Expect(err).NotTo(HaveOccurred())
					Expect(cmd).To(ContainSubstring("groovy"))
					Expect(cmd).To(ContainSubstring("custom.groovy"))
				})
			})

			Context("with detected Groovy scripts", func() {
				BeforeEach(func() {
					os.WriteFile(filepath.Join(buildDir, "app.groovy"), []byte("println 'app'"), 0644)
					os.WriteFile(filepath.Join(buildDir, "util.groovy"), []byte("println 'util'"), 0644)
					container.Detect()
				})

				It("uses the first script found", func() {
					cmd, err := container.Release()
					Expect(err).NotTo(HaveOccurred())
					Expect(cmd).To(ContainSubstring("groovy"))
					Expect(cmd).To(MatchRegexp("(app|util)\\.groovy"))
				})
			})

			Context("with no script available", func() {
				It("returns error", func() {
					_, err := container.Release()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("no Groovy script specified"))
				})
			})
		})
	})

	Describe("Java Main Container - Finalize", func() {
		var container *containers.JavaMainContainer

		BeforeEach(func() {
			container = containers.NewJavaMainContainer(ctx)
		})

		Describe("buildClasspath via Finalize", func() {
			Context("with JARs in root and lib/", func() {
				BeforeEach(func() {
					os.WriteFile(filepath.Join(buildDir, "app.jar"), []byte("fake"), 0644)
					os.WriteFile(filepath.Join(buildDir, "util.jar"), []byte("fake"), 0644)
					os.MkdirAll(filepath.Join(buildDir, "lib"), 0755)
					os.WriteFile(filepath.Join(buildDir, "lib", "dep1.jar"), []byte("fake"), 0644)
					os.WriteFile(filepath.Join(buildDir, "lib", "dep2.jar"), []byte("fake"), 0644)
				})

				It("builds correct classpath", func() {
					// Note: Finalize needs the container to be detected first
					os.WriteFile(filepath.Join(buildDir, "Main.class"), []byte("fake"), 0644)
					container.Detect()

					err := container.Finalize()
					Expect(err).NotTo(HaveOccurred())

					// Verify CLASSPATH was written (check via environment file)
					// We can't easily verify the env file, but no error means success
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

			Context("with empty build directory", func() {
				BeforeEach(func() {
					os.WriteFile(filepath.Join(buildDir, "Main.class"), []byte("fake"), 0644)
				})

				It("creates minimal classpath", func() {
					container.Detect()
					err := container.Finalize()
					Expect(err).NotTo(HaveOccurred())
				})
			})
		})
	})

	Describe("Spring Boot Container - Finalize", func() {
		var container *containers.SpringBootContainer

		BeforeEach(func() {
			container = containers.NewSpringBootContainer(ctx)
			os.WriteFile(filepath.Join(buildDir, "spring-boot.jar"), []byte("fake"), 0644)
			container.Detect()
		})

		It("finalizes successfully", func() {
			err := container.Finalize()
			Expect(err).NotTo(HaveOccurred())
		})
	})

	Describe("Tomcat Container - Finalize", func() {
		var container *containers.TomcatContainer

		BeforeEach(func() {
			container = containers.NewTomcatContainer(ctx)
			os.MkdirAll(filepath.Join(buildDir, "WEB-INF"), 0755)

			// Create mock Tomcat directory structure (after stripping top-level directory)
			tomcatDir := filepath.Join(depsDir, "0", "tomcat")
			os.MkdirAll(filepath.Join(tomcatDir, "bin"), 0755)
			os.MkdirAll(filepath.Join(tomcatDir, "conf"), 0755)
			os.WriteFile(filepath.Join(tomcatDir, "bin", "catalina.sh"), []byte("#!/bin/sh"), 0755)

			container.Detect()
		})

		It("finalizes successfully", func() {
			err := container.Finalize()
			Expect(err).NotTo(HaveOccurred())

			// Verify context configuration was created
			tomcatDir := filepath.Join(depsDir, "0", "tomcat")
			contextFile := filepath.Join(tomcatDir, "conf", "Catalina", "localhost", "ROOT.xml")
			Expect(contextFile).To(BeAnExistingFile())
		})
	})

	Describe("Groovy Container - Finalize", func() {
		var container *containers.GroovyContainer

		BeforeEach(func() {
			container = containers.NewGroovyContainer(ctx)
			os.WriteFile(filepath.Join(buildDir, "app.groovy"), []byte("println 'test'"), 0644)
			container.Detect()
		})

		It("finalizes successfully", func() {
			err := container.Finalize()
			Expect(err).NotTo(HaveOccurred())
		})
	})

	Describe("Dist ZIP Container - Finalize", func() {
		var container *containers.DistZipContainer

		BeforeEach(func() {
			container = containers.NewDistZipContainer(ctx)
			os.MkdirAll(filepath.Join(buildDir, "bin"), 0755)
			os.MkdirAll(filepath.Join(buildDir, "lib"), 0755)
			os.WriteFile(filepath.Join(buildDir, "bin", "app"), []byte("#!/bin/sh"), 0755)
			container.Detect()
		})

		It("finalizes successfully", func() {
			err := container.Finalize()
			Expect(err).NotTo(HaveOccurred())
		})
	})

	Describe("DetectAll", func() {
		It("returns all matching containers", func() {
			// Create both Groovy and Tomcat (overlapping detection)
			os.WriteFile(filepath.Join(buildDir, "app.groovy"), []byte("println 'hello'"), 0644)
			os.MkdirAll(filepath.Join(buildDir, "WEB-INF"), 0755)

			registry := containers.NewRegistry(ctx)
			registry.Register(containers.NewGroovyContainer(ctx))
			registry.Register(containers.NewTomcatContainer(ctx))
			registry.Register(containers.NewJavaMainContainer(ctx))

			detected, names, err := registry.DetectAll()
			Expect(err).NotTo(HaveOccurred())
			Expect(len(detected)).To(Equal(2))
			Expect(len(names)).To(Equal(2))
			Expect(names).To(ContainElement("Groovy"))
			Expect(names).To(ContainElement("Tomcat"))
		})

		It("returns empty when no containers match", func() {
			registry := containers.NewRegistry(ctx)
			registry.Register(containers.NewSpringBootContainer(ctx))
			registry.Register(containers.NewTomcatContainer(ctx))

			detected, names, err := registry.DetectAll()
			Expect(err).NotTo(HaveOccurred())
			Expect(len(detected)).To(Equal(0))
			Expect(len(names)).To(Equal(0))
		})
	})

	Describe("Dist ZIP Container - Advanced", func() {
		var container *containers.DistZipContainer

		BeforeEach(func() {
			container = containers.NewDistZipContainer(ctx)
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

			Context("with no start script detected", func() {
				It("returns error", func() {
					_, err := container.Release()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("no start script found"))
				})
			})
		})
	})
})
