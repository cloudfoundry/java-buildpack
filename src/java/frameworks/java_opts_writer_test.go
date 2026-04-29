package frameworks_test

import (
	"os"
	"os/exec"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/frameworks"
	"github.com/cloudfoundry/libbuildpack"
)

func newJavaOptsContext(buildDir, cacheDir, depsDir string) *common.Context {
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

var _ = Describe("Java Opts Writer", func() {
	var (
		buildDir string
		cacheDir string
		depsDir  string
		ctx      *common.Context
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "deps")
		Expect(err).NotTo(HaveOccurred())
		ctx = newJavaOptsContext(buildDir, cacheDir, depsDir)
	})

	AfterEach(func() {
		os.Unsetenv("JAVA_OPTS")
		os.RemoveAll(buildDir)
		os.RemoveAll(cacheDir)
		os.RemoveAll(depsDir)
	})

	Describe("Basic options", func() {
		It("writes JAVA_OPTS correctly", func() {
			javaOpts := "-Xmx512M -Xms256M"
			os.Setenv("JAVA_OPTS", javaOpts)

			Expect(os.Getenv("JAVA_OPTS")).To(Equal(javaOpts))
		})
	})

	Describe("CreateJavaOptsAssemblyScript", func() {
		It("handles multiline JAVA_OPTS from YAML block scalar without sed error", func() {
			// Reproduce the manifest pattern:
			//   JAVA_OPTS: >
			//     -javaagent:$HOME/BOOT-INF/classes/some-java-agent.jar
			//     -Xms512m
			//     -Xmx1024m
			// YAML '>' folds newlines to spaces, but CF may deliver them as literal newlines
			multilineJavaOpts := "-javaagent:$HOME/BOOT-INF/classes/some-java-agent.jar\n-Xms512m\n-Xmx1024m\n-XX:MaxDirectMemorySize=256m"

			err := frameworks.CreateJavaOptsAssemblyScript(ctx)
			Expect(err).NotTo(HaveOccurred())

			// Create an opts file that references $JAVA_OPTS (as frameworks do)
			optsDir := filepath.Join(depsDir, "0", "java_opts")
			Expect(os.MkdirAll(optsDir, 0755)).To(Succeed())
			Expect(os.WriteFile(filepath.Join(optsDir, "42_agent.opts"), []byte("-javaagent:somepath.jar $JAVA_OPTS"), 0644)).To(Succeed())

			// Run the generated profile.d script with multiline JAVA_OPTS
			scriptPath := filepath.Join(depsDir, "0", "profile.d", "00_java_opts.sh")
			cmd := exec.Command("bash", "-c",
				"source "+scriptPath+" && echo \"$JAVA_OPTS\"")
			cmd.Env = append(os.Environ(),
				"JAVA_OPTS="+multilineJavaOpts,
				"DEPS_DIR="+depsDir,
				"HOME=/home/vcap/app",
			)
			output, err := cmd.CombinedOutput()
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", string(output))
			Expect(string(output)).To(ContainSubstring("-Xms512m"))
		})
	})
})
