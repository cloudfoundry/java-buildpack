package frameworks

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
)

// jreExtDirs returns the runtime java.ext.dirs entries of the installed JRE (Java 8 only),
// e.g. "$DEPS_DIR/0/jre/jre8u513/jre/lib/ext:$DEPS_DIR/0/jre/jre8u513/lib/ext".
//
// The path is resolved at staging time from the JAVA_HOME set by the JRE finalize step and
// expressed relative to $DEPS_DIR/<idx>. $JAVA_HOME cannot be referenced in .opts files:
// they are expanded by profile.d/00_java_opts.sh, which is sourced before profile.d/java.sh
// exports JAVA_HOME, so $JAVA_HOME would expand to an empty string and the JRE's own
// extensions (SunJCE, SunEC, ...) would not be loaded.
func jreExtDirs(ctx *common.Context) string {
	runtimeJavaHome := "$JAVA_HOME"

	javaHome := os.Getenv("JAVA_HOME")
	depDir := ctx.Stager.DepDir()
	relPath, err := filepath.Rel(depDir, javaHome)
	if javaHome == "" || err != nil || relPath == ".." || strings.HasPrefix(relPath, ".."+string(filepath.Separator)) {
		ctx.Log.Warning("Unable to resolve JAVA_HOME (%q) relative to %s, falling back to $JAVA_HOME for java.ext.dirs", javaHome, depDir)
	} else {
		runtimeJavaHome = fmt.Sprintf("$DEPS_DIR/%s", ctx.Stager.DepsIdx())
		if relPath != "." {
			runtimeJavaHome += "/" + filepath.ToSlash(relPath)
		}
	}

	return fmt.Sprintf("%s/jre/lib/ext:%s/lib/ext", runtimeJavaHome, runtimeJavaHome)
}
