package jres

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
)

// CVE-2026-114938 ("Java4Shell") is a heap overflow in the AVX-512 Base64 decoder of HotSpot on x86-64.
// Disabling the Base64 intrinsics stops the vulnerable code from running. The option is a regular product flag on every
// platform, so it is safe on ARM64 too, but it does not exist before Java 9, so it is only ever added for Java 17 and later.
const base64MitigationOpt = "-XX:-UseBASE64Intrinsics"

// firstFixedBase64Version is the first release of each Java line that contains the fix (JDK-8393212).
// Releases of a line below it are mitigated. A line that is not listed is affected as well (17.0.6 and later, and every
// release from 18 on), so it is mitigated until a fixed release is added here.
var firstFixedBase64Version = map[int]string{
	17: "17.0.21.1",
	21: "21.0.13.1",
	25: "25.0.5.1",
}

// first Java 17 release that has the vulnerable x86 decoder; 17.0.0 to 17.0.5 do not have it
const firstAffectedJava17 = "17.0.6"

// profile.d script that adds the option to JDK_JAVA_OPTIONS, so that JVMs that do not get JAVA_OPTS are covered too:
// a custom start command, a task, a cf ssh session or a java process started by the application.
// JDK_JAVA_OPTIONS is read by the java launcher of Java 9 and later, which all know the option. Java 8 ignores the variable,
// while it would refuse to start with the option in JAVA_TOOL_OPTIONS ("Unrecognized VM option").
const base64MitigationProfileScript = "base64_intrinsics_mitigation.sh"

const base64MitigationProfileContent = `case " $JDK_JAVA_OPTIONS " in
  *" ` + base64MitigationOpt + ` "*) ;;
  *) export JDK_JAVA_OPTIONS="${JDK_JAVA_OPTIONS:+$JDK_JAVA_OPTIONS }` + base64MitigationOpt + `" ;;
esac
`

type base64MitigationConfig struct {
	Enabled        *bool `yaml:"enabled"`
	JdkJavaOptions *bool `yaml:"jdk_java_options"`
}

type base64MitigationJREConfig struct {
	Base64IntrinsicsMitigation base64MitigationConfig `yaml:"base64_intrinsics_mitigation"`
}

// needsBase64Mitigation reports whether a JRE with the given JAVA_VERSION (from its release file, e.g. "25.0.5.0.3")
// contains the vulnerable decoder and not yet the fix.
func needsBase64Mitigation(javaVersion string) (bool, error) {
	if strings.HasPrefix(strings.TrimSpace(javaVersion), "1.") {
		return false, nil
	}
	version, err := parseJavaVersion(javaVersion)
	if err != nil {
		return false, err
	}
	major := version[0]
	if major < 17 {
		return false, nil
	}
	if major == 17 && compareJavaVersions(version, mustParseJavaVersion(firstAffectedJava17)) < 0 {
		return false, nil
	}
	if fixed, ok := firstFixedBase64Version[major]; ok {
		return compareJavaVersions(version, mustParseJavaVersion(fixed)) < 0, nil
	}
	return true, nil
}

// parseJavaVersion parses the dotted numeric part of a JAVA_VERSION such as "21.0.13.0.3" or "17.0.21.1".
// A suffix such as "-ea" or "+9" is ignored. The old "1.8.0_422" format is rejected; needsBase64Mitigation handles it before.
func parseJavaVersion(v string) ([]int, error) {
	v = strings.TrimSpace(v)
	if i := strings.IndexAny(v, "+-_"); i >= 0 {
		v = v[:i]
	}
	if v == "" || strings.HasPrefix(v, "1.") {
		return nil, fmt.Errorf("unsupported Java version %q", v)
	}
	var out []int
	for _, part := range strings.Split(v, ".") {
		n, err := strconv.Atoi(part)
		if err != nil {
			return nil, fmt.Errorf("unsupported Java version %q", v)
		}
		out = append(out, n)
	}
	return out, nil
}

func mustParseJavaVersion(v string) []int {
	parsed, err := parseJavaVersion(v)
	if err != nil {
		panic(err)
	}
	return parsed
}

// compareJavaVersions compares dotted versions; a missing trailing element counts as 0, so 25.0.5 < 25.0.5.1.
func compareJavaVersions(a, b []int) int {
	for i := 0; i < len(a) || i < len(b); i++ {
		var x, y int
		if i < len(a) {
			x = a[i]
		}
		if i < len(b) {
			y = b[i]
		}
		if x != y {
			if x < y {
				return -1
			}
			return 1
		}
	}
	return 0
}

// readJavaVersion returns JAVA_VERSION from the release file of the JRE, which holds every segment of the
// version (e.g. "25.0.5.0.3"), unlike DetermineJavaVersion which only returns the major version.
func readJavaVersion(javaHome string) (string, error) {
	content, err := os.ReadFile(filepath.Join(javaHome, "release"))
	if err != nil {
		return "", fmt.Errorf("failed to read release file: %w", err)
	}
	for _, line := range strings.Split(string(content), "\n") {
		if strings.HasPrefix(line, "JAVA_VERSION=") {
			return strings.Trim(strings.TrimSpace(strings.TrimPrefix(line, "JAVA_VERSION=")), "\""), nil
		}
	}
	return "", fmt.Errorf("no JAVA_VERSION in release file")
}

// base64MitigationSettings reads the opt-outs from JBP_CONFIG_<JRE>_JRE: enabled turns the whole mitigation off,
// jdk_java_options turns off only the JDK_JAVA_OPTIONS part. Both default to true.
func (b *BaseJRE) base64MitigationSettings() (enabled, jdkJavaOptions bool) {
	envVarName := jreNameToDocumentedEnvVar[b.jreKey]
	if envVarName == "" {
		envVarName = fmt.Sprintf("JBP_CONFIG_%s", strings.ToUpper(strings.ReplaceAll(b.jreKey, "-", "_")))
	}
	config := os.Getenv(envVarName)
	if config == "" {
		return true, true
	}

	cfg := base64MitigationJREConfig{}
	if err := (common.YamlHandler{}).Unmarshal([]byte(config), &cfg); err != nil {
		b.ctx.Log.Warning("Failed to parse %s: %s", envVarName, err.Error())
		return true, true
	}
	mitigation := cfg.Base64IntrinsicsMitigation
	enabled = mitigation.Enabled == nil || *mitigation.Enabled
	jdkJavaOptions = mitigation.JdkJavaOptions == nil || *mitigation.JdkJavaOptions
	return enabled, jdkJavaOptions
}

// base64Mitigate applies the mitigation of CVE-2026-114938 when the JRE is affected, has no fix yet and the application did
// not opt out: -XX:-UseBASE64Intrinsics in JAVA_OPTS, and in JDK_JAVA_OPTIONS through a profile.d script.
func (b *BaseJRE) base64Mitigate() {
	if !b.base64Mitigation || b.javaHome == "" {
		return
	}

	javaVersion, err := readJavaVersion(b.javaHome)
	if err != nil {
		b.ctx.Log.Warning("Could not determine the %s version to check for CVE-2026-114938: %s", b.jreName, err.Error())
		return
	}
	needed, err := needsBase64Mitigation(javaVersion)
	if err != nil {
		b.ctx.Log.Warning("Could not check %s %s for CVE-2026-114938: %s", b.jreName, javaVersion, err.Error())
		return
	}
	if !needed {
		return
	}

	enabled, jdkJavaOptions := b.base64MitigationSettings()
	if !enabled {
		b.ctx.Log.Warning("%s %s is affected by CVE-2026-114938, but the mitigation %s is disabled by configuration", b.jreName, javaVersion, base64MitigationOpt)
		return
	}

	b.ctx.Log.Warning("%s %s is affected by CVE-2026-114938 (Java4Shell): adding %s to JAVA_OPTS and JDK_JAVA_OPTIONS. Update to a fixed JRE release to remove it; opt out with JBP_CONFIG_*_JRE '{base64_intrinsics_mitigation: {enabled: false}}', or '{base64_intrinsics_mitigation: {jdk_java_options: false}}' to keep only JAVA_OPTS", b.jreName, javaVersion, base64MitigationOpt)

	if err := WriteJavaOpts(b.ctx, base64MitigationOpt); err != nil {
		b.ctx.Log.Warning("Failed to write %s JAVA_OPTS: %s", b.jreName, err.Error())
	}
	if jdkJavaOptions {
		if err := b.ctx.Stager.WriteProfileD(base64MitigationProfileScript, base64MitigationProfileContent); err != nil {
			b.ctx.Log.Warning("Failed to write %s: %s", base64MitigationProfileScript, err.Error())
		}
	}
}
