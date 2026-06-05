package frameworks_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"

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

	Describe("CreateJavaOptsAssemblyScript", func() {
		setupScript := func(javaOpts string, optsFileContent string) string {
			err := frameworks.CreateJavaOptsAssemblyScript(ctx)
			Expect(err).NotTo(HaveOccurred())

			optsDir := filepath.Join(depsDir, "0", "java_opts")
			Expect(os.MkdirAll(optsDir, 0755)).To(Succeed())
			Expect(os.WriteFile(filepath.Join(optsDir, "42_agent.opts"), []byte(optsFileContent), 0644)).To(Succeed())

			return filepath.Join(depsDir, "0", "profile.d", "00_java_opts.sh")
		}

		runWithEnv := func(scriptPath, javaOpts, bashExpr string) (string, error) {
			cmd := exec.Command("bash", "-c", "source "+scriptPath+" && "+bashExpr)
			cmd.Env = append(os.Environ(),
				"JAVA_OPTS="+javaOpts,
				"DEPS_DIR="+depsDir,
				"HOME=/home/vcap/app",
			)
			output, err := cmd.CombinedOutput()
			return string(output), err
		}

		runScript := func(javaOpts string, optsFileContent string) (string, error) {
			scriptPath := setupScript(javaOpts, optsFileContent)
			return runWithEnv(scriptPath, javaOpts, `printf '%s\n' "$JAVA_OPTS"`)
		}

		// runStartCommand simulates the actual JVM invocation:
		//   eval "exec $JAVA_HOME/bin/java $JAVA_OPTS -jar app.jar"
		// Returns the argument list java would receive (one arg per line).
		runStartCommand := func(javaOpts string, optsFileContent string) (string, error) {
			scriptPath := setupScript(javaOpts, optsFileContent)
			// Simulate: eval "exec java $JAVA_OPTS" — quoted string prevents bash glob-expansion.
			// eval then re-parses the string, honouring embedded quotes in $JAVA_OPTS.
			return runWithEnv(scriptPath, javaOpts,
				`eval "set -- $JAVA_OPTS"; printf '%s\n' "$@"`)
		}

		It("handles multiline JAVA_OPTS from YAML block scalar without sed error", func() {
			// Reproduce the manifest pattern:
			//   JAVA_OPTS: >
			//     -javaagent:$HOME/BOOT-INF/lib/agent.jar
			//     -XX:+UseZGC
			// YAML '>' folds newlines to spaces, but CF may deliver them as literal newlines
			multilineJavaOpts := "-javaagent:$HOME/BOOT-INF/lib/agent.jar\n-XX:+UseZGC\n-XX:+AlwaysPreTouch"

			output, err := runScript(multilineJavaOpts, "-javaagent:somepath.jar $JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring("-XX:+UseZGC"))
		})

		It("handles pipe character in JAVA_OPTS (e.g. javaagent options) without sed error", func() {
			// Reproduce the manifest pattern:
			//   JAVA_OPTS: >
			//     -javaagent:$HOME/BOOT-INF/lib/jfr-exporter.jar=enableExecutorMBeans|disableMyFeature
			pipeJavaOpts := "-javaagent:$HOME/BOOT-INF/lib/jfr-exporter.jar=enableExecutorMBeans|disableMyFeature"

			output, err := runScript(pipeJavaOpts, "-javaagent:somepath.jar $JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring("enableExecutorMBeans|disableMyFeature"))
		})

		It("expands $HOME in opts file content", func() {
			output, err := runScript("", "-javaagent:$HOME/BOOT-INF/lib/agent.jar")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring("-javaagent:/home/vcap/app/BOOT-INF/lib/agent.jar"))
		})

		It("expands $DEPS_DIR in opts file content", func() {
			output, err := runScript("", "-Djava.security.properties=$DEPS_DIR/0/security.properties")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring("-Djava.security.properties=" + depsDir + "/0/security.properties"))
		})

		It("preserves literal -n from opts file content", func() {
			output, err := runScript("", "-n")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(strings.TrimSpace(output)).To(Equal("-n"))
		})

		// Regression tests for issue #1301: xargs strips quotes, breaking quoted JVM args
		It("preserves quoted value with spaces in JAVA_OPTS", func() {
			// JAVA_OPTS='-Dfoo="bar baz"' — xargs removes the quotes from USER_JAVA_OPTS,
			// so when eval exec java $JAVA_OPTS is called, -Dfoo=bar and baz become separate args
			output, err := runScript(`-Dfoo="bar baz"`, "$JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring(`-Dfoo="bar baz"`))
		})

		It("preserves cron expression with glob characters in JAVA_OPTS", func() {
			// JAVA_OPTS='-DcronSched="0 */7 * * * *"' — xargs strips quotes, then * expands via glob
			// when eval exec java $JAVA_OPTS is invoked, corrupting the cron expression
			output, err := runScript(`-DcronSched="0 */7 * * * *"`, "$JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring(`-DcronSched="0 */7 * * * *"`))
		})

		It("preserves multiple quoted args in JAVA_OPTS", func() {
			// Multiple quoted values — xargs strips all quotes, each space-containing value splits
			output, err := runScript(`-Dfoo="bar baz" -Dother="qux quux"`, "$JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring(`-Dfoo="bar baz"`))
			Expect(output).To(ContainSubstring(`-Dother="qux quux"`))
		})

		It("preserves backslashes in JAVA_OPTS values", func() {
			// xargs treats backslash as escape char: C:\path\to\app -> C:pathtoapp
			// Affects regex patterns and any path using backslash notation
			output, err := runScript(`-DregEx="[a-z]+(.*)" -Dpattern=foo\|bar`, "$JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring(`-DregEx="[a-z]+(.*)"`))
			Expect(output).To(ContainSubstring(`foo\|bar`))
		})

		It("preserves leading -n argument in JAVA_OPTS", func() {
			output, err := runScript(`-n -Dfoo=bar`, "$JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring(`-n -Dfoo=bar`))
		})

		It("preserves ampersand in JAVA_OPTS values during placeholder substitution", func() {
			output, err := runScript(`-Dfoo=a&b`, "$JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring(`-Dfoo=a&b`))
		})

		It("preserves backslashes in JAVA_OPTS values during placeholder substitution", func() {
			output, err := runScript(`-Dpath=C:\tmp\app`, "$JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring(`-Dpath=C:\tmp\app`))
		})

		// Full invocation cycle test for issue #1301:
		// Verifies that the quoted eval "exec ... $JAVA_OPTS" form delivers the correct
		// argument to java — glob chars in $JAVA_OPTS are not expanded.
		It("does not glob-expand * in cron expression when invoking java", func() {
			output, err := runStartCommand(`-DcronSched="0 */7 * * * *"`, "$JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			// Java receives exactly one arg: -DcronSched=0 */7 * * * *
			Expect(strings.TrimSpace(output)).To(Equal("-DcronSched=0 */7 * * * *"))
		})
	})
})
