package frameworks_test

import (
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/frameworks"
	"github.com/cloudfoundry/libbuildpack"
)

func newJMAContext(buildDir, cacheDir, depsDir string) *common.Context {
	logger := libbuildpack.NewLogger(GinkgoWriter)
	manifest := &libbuildpack.Manifest{}
	installer := &libbuildpack.Installer{}
	stager := libbuildpack.NewStager([]string{buildDir, cacheDir, depsDir, "0"}, logger, manifest)
	return &common.Context{
		Stager:    stager,
		Manifest:  manifest,
		Installer: installer,
		Log:       logger,
		Command:   &libbuildpack.Command{},
	}
}

// installJMAAgent creates a versioned JMA JAR under depsDir.
func installJMAAgent(depsDir, version string) {
	agentDir := filepath.Join(depsDir, "0", "java_memory_assistant")
	Expect(os.MkdirAll(agentDir, 0755)).To(Succeed())
	Expect(os.WriteFile(
		filepath.Join(agentDir, "java-memory-assistant-"+version+".jar"),
		[]byte("fake jar"), 0644,
	)).To(Succeed())
}

var _ = Describe("Java Memory Assistant", func() {
	var (
		fw       *frameworks.JavaMemoryAssistantFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "jma-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "jma-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "jma-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewJavaMemoryAssistantFramework(newJMAContext(buildDir, cacheDir, depsDir))
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(cacheDir)
		os.RemoveAll(depsDir)
		os.Unsetenv("JBP_CONFIG_JAVA_MEMORY_ASSISTANT")
		os.Unsetenv("VCAP_SERVICES")
		os.Unsetenv("JAVA_HOME")
	})

	Describe("Detect", func() {
		Context("with no configuration set", func() {
			It("returns empty string (disabled by default)", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with JBP_CONFIG_JAVA_MEMORY_ASSISTANT enabled: true", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_JAVA_MEMORY_ASSISTANT", "enabled: true")
			})

			It("returns 'Java Memory Assistant'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("Java Memory Assistant"))
			})
		})

		Context("with JBP_CONFIG_JAVA_MEMORY_ASSISTANT enabled: false", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_JAVA_MEMORY_ASSISTANT", "enabled: false")
			})

			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with invalid JBP_CONFIG_JAVA_MEMORY_ASSISTANT YAML", func() {
			BeforeEach(func() {
				os.Setenv("JBP_CONFIG_JAVA_MEMORY_ASSISTANT", "enabled: [not a bool")
			})

			It("returns empty string without error", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})
	})

	Describe("Finalize", func() {
		Context("with agent JAR present", func() {
			BeforeEach(func() {
				installJMAAgent(depsDir, "1.2.3")
			})

			It("writes the opts file", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "java_opts", "28_java_memory_assistant.opts")).To(BeAnExistingFile())
			})

			It("opts file contains -javaagent pointing to the runtime JAR path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "28_java_memory_assistant.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-javaagent:"))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/java_memory_assistant/java-memory-assistant-1.2.3.jar"))
			})

			It("opts file does not embed the staging-time absolute path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "28_java_memory_assistant.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(depsDir))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR"))
			})

			It("uses priority prefix 28 in the filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				entries, err := os.ReadDir(filepath.Join(depsDir, "0", "java_opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(entries).To(HaveLen(1))
				Expect(entries[0].Name()).To(Equal("28_java_memory_assistant.opts"))
			})

			It("opts file contains default check interval", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "28_java_memory_assistant.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Djma.check_interval=5s"))
			})

			It("opts file contains default max frequency", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "28_java_memory_assistant.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Djma.max_frequency=1/1m"))
			})

			It("opts file contains default old_gen threshold", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "28_java_memory_assistant.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Djma.thresholds.old_gen=>600MB"))
			})

			It("opts file contains heap dump folder defaulting to $PWD", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "28_java_memory_assistant.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Djma.heap_dump_folder=$PWD"))
			})
		})

		Context("with custom check_interval via JBP_CONFIG_JAVA_MEMORY_ASSISTANT", func() {
			BeforeEach(func() {
				installJMAAgent(depsDir, "1.2.3")
				os.Setenv("JBP_CONFIG_JAVA_MEMORY_ASSISTANT", "agent:\n  check_interval: 10s")
			})

			It("opts file contains the configured check interval", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "28_java_memory_assistant.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Djma.check_interval=10s"))
			})
		})

		Context("with custom max_frequency via JBP_CONFIG_JAVA_MEMORY_ASSISTANT", func() {
			BeforeEach(func() {
				installJMAAgent(depsDir, "1.2.3")
				os.Setenv("JBP_CONFIG_JAVA_MEMORY_ASSISTANT", "agent:\n  max_frequency: 2/5m")
			})

			It("opts file contains the configured max frequency", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "28_java_memory_assistant.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Djma.max_frequency=2/5m"))
			})
		})

		Context("with custom old_gen threshold via JBP_CONFIG_JAVA_MEMORY_ASSISTANT", func() {
			BeforeEach(func() {
				installJMAAgent(depsDir, "1.2.3")
				os.Setenv("JBP_CONFIG_JAVA_MEMORY_ASSISTANT", "agent:\n  thresholds:\n    old_gen: \">80%\"")
			})

			It("opts file contains the configured old_gen threshold", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "28_java_memory_assistant.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Djma.thresholds.old_gen=>80%"))
			})
		})

		Context("with heap threshold set via JBP_CONFIG_JAVA_MEMORY_ASSISTANT", func() {
			BeforeEach(func() {
				installJMAAgent(depsDir, "1.2.3")
				os.Setenv("JBP_CONFIG_JAVA_MEMORY_ASSISTANT", "agent:\n  thresholds:\n    heap: \">90%\"")
			})

			It("opts file contains -Djma.thresholds.heap", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "28_java_memory_assistant.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Djma.thresholds.heap=>90%"))
			})
		})

		Context("with log_level set via JBP_CONFIG_JAVA_MEMORY_ASSISTANT", func() {
			BeforeEach(func() {
				installJMAAgent(depsDir, "1.2.3")
				os.Setenv("JBP_CONFIG_JAVA_MEMORY_ASSISTANT", "agent:\n  log_level: DEBUG")
			})

			It("opts file contains -Djma.log_level=DEBUG", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "28_java_memory_assistant.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Djma.log_level=DEBUG"))
			})
		})

		Context("with a heap-dump volume service in VCAP_SERVICES", func() {
			BeforeEach(func() {
				installJMAAgent(depsDir, "1.2.3")
				os.Setenv("VCAP_SERVICES", `{"user-provided":[{"name":"heap-dump","label":"user-provided","tags":[],"credentials":{}}]}`)
			})

			It("opts file contains heap dump folder pointing to the volume mount", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "28_java_memory_assistant.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Djma.heap_dump_folder=$HEAP_DUMP_VOLUME/heapdumps"))
			})
		})

		Context("with Java 9+ (JAVA_HOME set to a mock java 11 installation)", func() {
			BeforeEach(func() {
				installJMAAgent(depsDir, "1.2.3")
				// Create a fake java binary that reports version 11
				javaHome := filepath.Join(depsDir, "java11")
				javabin := filepath.Join(javaHome, "bin")
				Expect(os.MkdirAll(javabin, 0755)).To(Succeed())
				releaseFile := filepath.Join(javaHome, "release")
				Expect(os.WriteFile(releaseFile, []byte(`JAVA_VERSION="11.0.2"`), 0644)).To(Succeed())
				os.Setenv("JAVA_HOME", javaHome)
			})

			It("opts file contains --add-opens flag", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "28_java_memory_assistant.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("--add-opens jdk.management/com.sun.management.internal=ALL-UNNAMED"))
			})
		})

		Context("without JAVA_HOME set", func() {
			BeforeEach(func() {
				installJMAAgent(depsDir, "1.2.3")
				os.Unsetenv("JAVA_HOME")
			})

			It("succeeds and writes the opts file without --add-opens", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "28_java_memory_assistant.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring("--add-opens"))
			})
		})

		Context("when the agent JAR is not present", func() {
			It("returns an error", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("Java Memory Assistant JAR not found"))
			})
		})

		Context("with the exact user config: enabled, heap threshold 80%, heap_dump_folder /home/vcap/, check_interval 5m", func() {
			BeforeEach(func() {
				installJMAAgent(depsDir, "1.2.3")
				os.Setenv("JBP_CONFIG_JAVA_MEMORY_ASSISTANT",
					`{enabled : true, agent: { thresholds : { heap: "80%" }, heap_dump_folder: /home/vcap/, check_interval: 5m } }`)
			})

			It("opts file contains -Djma.thresholds.heap=80%", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "28_java_memory_assistant.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Djma.thresholds.heap=80%"))
			})

			It("opts file contains -Djma.heap_dump_folder=/home/vcap/", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "28_java_memory_assistant.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Djma.heap_dump_folder=/home/vcap/"))
			})

			It("opts file contains -Djma.check_interval=5m", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "java_opts", "28_java_memory_assistant.opts"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("-Djma.check_interval=5m"))
			})
		})
	})
})
