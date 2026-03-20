package frameworks_test

import (
	"os"
	"path/filepath"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/frameworks"
	"github.com/cloudfoundry/libbuildpack"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("VCAP Services", func() {
	Describe("HasService", func() {
		It("returns true when service exists", func() {
			vcapServices := frameworks.VCAPServices{
				"newrelic": []frameworks.VCAPService{
					{Name: "newrelic-service", Label: "newrelic"},
				},
			}

			Expect(vcapServices.HasService("newrelic")).To(BeTrue())
		})

		It("returns false when service does not exist", func() {
			vcapServices := frameworks.VCAPServices{
				"newrelic": []frameworks.VCAPService{
					{Name: "newrelic-service", Label: "newrelic"},
				},
			}

			Expect(vcapServices.HasService("appdynamics")).To(BeFalse())
		})
	})

	Describe("GetService", func() {
		It("returns service when it exists", func() {
			vcapServices := frameworks.VCAPServices{
				"newrelic": []frameworks.VCAPService{
					{Name: "my-newrelic", Label: "newrelic"},
				},
			}

			service := vcapServices.GetService("newrelic")
			Expect(service).NotTo(BeNil())
			Expect(service.Name).To(Equal("my-newrelic"))
		})

		It("returns nil when service does not exist", func() {
			vcapServices := frameworks.VCAPServices{
				"newrelic": []frameworks.VCAPService{
					{Name: "my-newrelic", Label: "newrelic"},
				},
			}

			service := vcapServices.GetService("appdynamics")
			Expect(service).To(BeNil())
		})
	})

	Describe("HasTag", func() {
		It("returns true when tag exists", func() {
			vcapServices := frameworks.VCAPServices{
				"user-provided": []frameworks.VCAPService{
					{
						Name:  "my-monitoring",
						Label: "user-provided",
						Tags:  []string{"monitoring", "apm"},
					},
				},
			}

			Expect(vcapServices.HasTag("apm")).To(BeTrue())
		})

		It("returns false when tag does not exist", func() {
			vcapServices := frameworks.VCAPServices{
				"user-provided": []frameworks.VCAPService{
					{
						Name:  "my-monitoring",
						Label: "user-provided",
						Tags:  []string{"monitoring", "apm"},
					},
				},
			}

			Expect(vcapServices.HasTag("database")).To(BeFalse())
		})
	})

	Describe("GetVCAPServices", func() {
		AfterEach(func() {
			os.Unsetenv("VCAP_SERVICES")
		})

		Context("with empty VCAP_SERVICES", func() {
			It("returns empty services map", func() {
				os.Setenv("VCAP_SERVICES", "")

				services, err := frameworks.GetVCAPServices()
				Expect(err).NotTo(HaveOccurred())
				Expect(services).To(HaveLen(0))
			})
		})

		Context("with valid VCAP_SERVICES JSON", func() {
			It("parses services correctly", func() {
				vcapJSON := `{
					"newrelic": [{
						"name": "newrelic-service",
						"label": "newrelic",
						"tags": ["apm", "monitoring"],
						"credentials": {
							"licenseKey": "test-key-123"
						}
					}]
				}`

				os.Setenv("VCAP_SERVICES", vcapJSON)

				services, err := frameworks.GetVCAPServices()
				Expect(err).NotTo(HaveOccurred())
				Expect(services.HasService("newrelic")).To(BeTrue())

				service := services.GetService("newrelic")
				Expect(service).NotTo(BeNil())
				Expect(service.Name).To(Equal("newrelic-service"))

				licenseKey, ok := service.Credentials["licenseKey"].(string)
				Expect(ok).To(BeTrue())
				Expect(licenseKey).To(Equal("test-key-123"))
			})
		})

		Context("with multiple services", func() {
			It("handles multiple service instances", func() {
				vcapJSON := `{
					"newrelic": [{
						"name": "newrelic-1",
						"label": "newrelic"
					}, {
						"name": "newrelic-2",
						"label": "newrelic"
					}],
					"appdynamics": [{
						"name": "appdynamics-1",
						"label": "appdynamics"
					}]
				}`

				os.Setenv("VCAP_SERVICES", vcapJSON)

				services, err := frameworks.GetVCAPServices()
				Expect(err).NotTo(HaveOccurred())
				Expect(services.HasService("newrelic")).To(BeTrue())
				Expect(services.HasService("appdynamics")).To(BeTrue())

				nrService := services.GetService("newrelic")
				Expect(nrService).NotTo(BeNil())
				Expect(nrService.Name).To(Equal("newrelic-1"))
			})
		})

		Context("with user-provided services with tags", func() {
			It("detects tags correctly", func() {
				vcapJSON := `{
					"user-provided": [{
						"name": "my-apm",
						"label": "user-provided",
						"tags": ["apm", "newrelic", "monitoring"],
						"credentials": {
							"licenseKey": "user-key"
						}
					}]
				}`

				os.Setenv("VCAP_SERVICES", vcapJSON)

				services, err := frameworks.GetVCAPServices()
				Expect(err).NotTo(HaveOccurred())
				Expect(services.HasTag("apm")).To(BeTrue())
				Expect(services.HasTag("newrelic")).To(BeTrue())
				Expect(services.HasTag("monitoring")).To(BeTrue())
				Expect(services.HasTag("database")).To(BeFalse())
			})
		})

		Context("with invalid JSON", func() {
			It("returns error", func() {
				os.Setenv("VCAP_SERVICES", `{invalid json}`)

				services, err := frameworks.GetVCAPServices()
				Expect(err).To(HaveOccurred())
				Expect(services).To(BeNil())
			})
		})

		Context("with empty credentials", func() {
			It("parses service with empty credentials map", func() {
				vcapJSON := `{
					"newrelic": [{
						"name": "newrelic-service",
						"label": "newrelic",
						"credentials": {}
					}]
				}`

				os.Setenv("VCAP_SERVICES", vcapJSON)

				services, err := frameworks.GetVCAPServices()
				Expect(err).NotTo(HaveOccurred())
				Expect(services.HasService("newrelic")).To(BeTrue())

				service := services.GetService("newrelic")
				Expect(service).NotTo(BeNil())
				Expect(service.Credentials).NotTo(BeNil())
				Expect(service.Credentials).To(HaveLen(0))
			})
		})
	})
})

var _ = Describe("Framework Registry", func() {
	var (
		ctx      *common.Context
		registry *frameworks.Registry
		tmpDir   string
	)

	BeforeEach(func() {
		var err error
		tmpDir, err = os.MkdirTemp("", "java-buildpack-test-*")
		Expect(err).NotTo(HaveOccurred())

		logger := libbuildpack.NewLogger(os.Stdout)
		stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, &libbuildpack.Manifest{})
		manifest := &libbuildpack.Manifest{}
		installer := &libbuildpack.Installer{}
		command := &libbuildpack.Command{}

		ctx = &common.Context{
			Stager:    stager,
			Manifest:  manifest,
			Installer: installer,
			Log:       logger,
			Command:   command,
		}

		registry = frameworks.NewRegistry(ctx)
	})

	AfterEach(func() {
		os.RemoveAll(tmpDir)
		os.Unsetenv("VCAP_SERVICES")
	})

	Describe("DetectAll", func() {
		It("detects no frameworks when no services are bound", func() {
			registry.Register(frameworks.NewNewRelicFramework(ctx))
			registry.Register(frameworks.NewAppDynamicsFramework(ctx))

			detected, names, err := registry.DetectAll()
			Expect(err).NotTo(HaveOccurred())
			Expect(detected).To(HaveLen(0))
			Expect(names).To(HaveLen(0))
		})

		It("detects multiple frameworks", func() {
			registry.Register(frameworks.NewNewRelicFramework(ctx))
			registry.Register(frameworks.NewAppDynamicsFramework(ctx))

			vcapJSON := `{
				"newrelic": [{
					"name": "newrelic-service",
					"label": "newrelic",
					"credentials": {"licenseKey": "test-key"}
				}],
				"appdynamics": [{
					"name": "appdynamics-service",
					"label": "appdynamics",
					"credentials": {"account-access-key": "test-key"}
				}]
			}`
			os.Setenv("VCAP_SERVICES", vcapJSON)

			detected, names, err := registry.DetectAll()
			Expect(err).NotTo(HaveOccurred())
			Expect(detected).To(HaveLen(2))
			Expect(names).To(ContainElements("New Relic Agent", "AppDynamics Agent"))
		})
	})
})

var _ = Describe("New Relic Framework", func() {
	var (
		ctx       *common.Context
		framework frameworks.Framework
		tmpDir    string
	)

	BeforeEach(func() {
		var err error
		tmpDir, err = os.MkdirTemp("", "java-buildpack-test-*")
		Expect(err).NotTo(HaveOccurred())

		logger := libbuildpack.NewLogger(os.Stdout)
		stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, &libbuildpack.Manifest{})

		ctx = &common.Context{
			Stager: stager,
			Log:    logger,
		}

		framework = frameworks.NewNewRelicFramework(ctx)
	})

	AfterEach(func() {
		os.RemoveAll(tmpDir)
		os.Unsetenv("VCAP_SERVICES")
	})

	Describe("Detect", func() {
		Context("without service binding", func() {
			It("does not detect", func() {
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with New Relic service", func() {
			It("detects successfully", func() {
				vcapJSON := `{
					"newrelic": [{
						"name": "newrelic-service",
						"label": "newrelic",
						"credentials": {
							"licenseKey": "test-key"
						}
					}]
				}`
				os.Setenv("VCAP_SERVICES", vcapJSON)

				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("New Relic Agent"))
			})
		})
	})
})

var _ = Describe("AppDynamics Framework", func() {
	var (
		ctx       *common.Context
		framework frameworks.Framework
		tmpDir    string
	)

	BeforeEach(func() {
		var err error
		tmpDir, err = os.MkdirTemp("", "java-buildpack-test-*")
		Expect(err).NotTo(HaveOccurred())

		logger := libbuildpack.NewLogger(os.Stdout)
		stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, &libbuildpack.Manifest{})

		ctx = &common.Context{
			Stager: stager,
			Log:    logger,
		}

		framework = frameworks.NewAppDynamicsFramework(ctx)
	})

	AfterEach(func() {
		os.RemoveAll(tmpDir)
		os.Unsetenv("VCAP_SERVICES")
	})

	Describe("Detect", func() {
		Context("without service binding", func() {
			It("does not detect", func() {
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with AppDynamics service", func() {
			It("detects successfully", func() {
				vcapJSON := `{
					"appdynamics": [{
						"name": "appdynamics-service",
						"label": "appdynamics",
						"credentials": {
							"host-name": "controller.example.com",
							"account-name": "test-account",
							"account-access-key": "test-key"
						}
					}]
				}`
				os.Setenv("VCAP_SERVICES", vcapJSON)

				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("AppDynamics Agent"))
			})
		})
	})
})

var _ = Describe("Java Opts Framework", func() {
	var (
		ctx       *common.Context
		framework frameworks.Framework
		tmpDir    string
		depsDir   string
	)

	BeforeEach(func() {
		var err error
		tmpDir, err = os.MkdirTemp("", "java-buildpack-test-*")
		Expect(err).NotTo(HaveOccurred())

		depsDir = filepath.Join(tmpDir, "deps")
		err = os.MkdirAll(filepath.Join(depsDir, "0"), 0755)
		Expect(err).NotTo(HaveOccurred())

		logger := libbuildpack.NewLogger(os.Stdout)
		manifest := &libbuildpack.Manifest{}
		stager := libbuildpack.NewStager([]string{tmpDir, "", depsDir, "0"}, logger, manifest)

		ctx = &common.Context{
			Stager:   stager,
			Manifest: manifest,
			Log:      logger,
		}

		framework = frameworks.NewJavaOptsFramework(ctx)
	})

	AfterEach(func() {
		os.RemoveAll(tmpDir)
		os.Unsetenv("JBP_CONFIG_JAVA_OPTS")
	})

	Describe("Detect", func() {
		Context("with default configuration", func() {
			It("detects (from_environment: true by default)", func() {
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Java Opts"))
			})
		})

		Context("with custom java_opts", func() {
			It("detects successfully", func() {
				os.Setenv("JBP_CONFIG_JAVA_OPTS", `{java_opts: ["-Xmx512m"]}`)

				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Java Opts"))
			})
		})

		Context("with from_environment disabled", func() {
			It("does not detect without custom opts", func() {
				os.Setenv("JBP_CONFIG_JAVA_OPTS", "{from_environment: false}")

				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with legacy format", func() {
			It("handles backward compatibility", func() {
				os.Setenv("JBP_CONFIG_JAVA_OPTS", "[from_environment: false, java_opts: -Xmx512M -Xms256M -Xss1M -XX:MetaspaceSize=157286K -XX:MaxMetaspaceSize=314572K -DoptionKey=optionValue]")

				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Java Opts"))
			})
		})
	})

	Describe("Supply", func() {
		It("is a no-op", func() {
			err := framework.Supply()
			Expect(err).NotTo(HaveOccurred())
		})
	})

	Describe("Finalize", func() {
		Context("with legacy format", func() {
			It("parses and writes opts correctly", func() {
				os.Setenv("JBP_CONFIG_JAVA_OPTS", "[from_environment: false, java_opts: -Xmx512M -Xms256M -Xss1M -XX:MetaspaceSize=157286K -XX:MaxMetaspaceSize=314572K -DoptionKey=optionValue]")

				_, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())

				err = framework.Finalize()
				Expect(err).NotTo(HaveOccurred())

				optsFile := filepath.Join(depsDir, "0", "java_opts", "99_user_java_opts.opts")
				data, err := os.ReadFile(optsFile)
				Expect(err).NotTo(HaveOccurred())

				javaOpts := string(data)
				Expect(javaOpts).To(ContainSubstring("-Xmx512M"))
				Expect(javaOpts).To(ContainSubstring("-Xms256M"))
				Expect(javaOpts).To(ContainSubstring("-Xss1M"))
				Expect(javaOpts).To(ContainSubstring("-XX:MetaspaceSize=157286K"))
				Expect(javaOpts).To(ContainSubstring("-XX:MaxMetaspaceSize=314572K"))
				Expect(javaOpts).To(ContainSubstring("-DoptionKey=optionValue"))
			})
		})
	})
})

var _ = Describe("Spring Auto-reconfiguration Framework", func() {
	var (
		ctx       *common.Context
		framework frameworks.Framework
		tmpDir    string
	)

	BeforeEach(func() {
		var err error
		tmpDir, err = os.MkdirTemp("", "java-buildpack-test-*")
		Expect(err).NotTo(HaveOccurred())

		logger := libbuildpack.NewLogger(os.Stdout)
		manifest := &libbuildpack.Manifest{}
		stager := libbuildpack.NewStager([]string{tmpDir, "", "0"}, logger, manifest)

		ctx = &common.Context{
			Stager:   stager,
			Manifest: manifest,
			Log:      logger,
		}

		framework = frameworks.NewSpringAutoReconfigurationFramework(ctx)
	})

	AfterEach(func() {
		os.RemoveAll(tmpDir)
		os.Unsetenv("JBP_CONFIG_SPRING_AUTO_RECONFIGURATION")
	})

	Describe("Detect", func() {
		Context("without Spring application", func() {
			It("does not detect", func() {
				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with Spring application and explicitly enabled", func() {
			It("detects successfully", func() {
				bootInfLib := filepath.Join(tmpDir, "BOOT-INF", "lib")
				err := os.MkdirAll(bootInfLib, 0755)
				Expect(err).NotTo(HaveOccurred())

				springCoreJar := filepath.Join(bootInfLib, "spring-core-5.3.29.jar")
				err = os.WriteFile(springCoreJar, []byte("fake jar"), 0644)
				Expect(err).NotTo(HaveOccurred())

				os.Setenv("JBP_CONFIG_SPRING_AUTO_RECONFIGURATION", "{enabled: true}")

				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Spring Auto-reconfiguration"))
			})
		})

		Context("with java-cfenv present", func() {
			It("does not detect", func() {
				bootInfLib := filepath.Join(tmpDir, "BOOT-INF", "lib")
				err := os.MkdirAll(bootInfLib, 0755)
				Expect(err).NotTo(HaveOccurred())

				springCoreJar := filepath.Join(bootInfLib, "spring-core-5.3.29.jar")
				err = os.WriteFile(springCoreJar, []byte("fake jar"), 0644)
				Expect(err).NotTo(HaveOccurred())

				javaCfEnvJar := filepath.Join(bootInfLib, "java-cfenv-boot-3.1.5.jar")
				err = os.WriteFile(javaCfEnvJar, []byte("fake jar"), 0644)
				Expect(err).NotTo(HaveOccurred())

				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("when explicitly disabled", func() {
			It("does not detect", func() {
				bootInfLib := filepath.Join(tmpDir, "BOOT-INF", "lib")
				err := os.MkdirAll(bootInfLib, 0755)
				Expect(err).NotTo(HaveOccurred())

				springCoreJar := filepath.Join(bootInfLib, "spring-core-5.3.29.jar")
				err = os.WriteFile(springCoreJar, []byte("fake jar"), 0644)
				Expect(err).NotTo(HaveOccurred())

				os.Setenv("JBP_CONFIG_SPRING_AUTO_RECONFIGURATION", "{enabled: false}")

				name, err := framework.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})
	})
})
