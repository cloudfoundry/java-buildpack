package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"syscall"

	"github.com/cloudfoundry/java-buildpack/src/java/javaexec"
)

// The javaexec launcher replaces the runtime `eval "exec java $JAVA_OPTS <args>"`
// start command. It is invoked as:
//
// javaexec <java-executable> [trusted args...]
//
// It reads JAVA_OPTS from the environment, tokenizes it without a shell (no
// expansion, no command substitution, no globbing), and execs the JVM with
// [java, <JAVA_OPTS tokens...>, <trusted args...>]. Because it execs, the JVM
// replaces this process: no extra wrapper process remains.
func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "javaexec: usage: javaexec <java-executable> [args...]")
		os.Exit(2)
	}

	java := os.Args[1]
	trusted := os.Args[2:]

	// syscall.Exec does not search PATH; resolve a bare command name (e.g. the
	// Play container's "java") to an absolute path.
	if !strings.ContainsRune(java, '/') {
		resolved, err := exec.LookPath(java)
		if err != nil {
			fmt.Fprintf(os.Stderr, "javaexec: cannot find %q on PATH: %v\n", java, err)
			os.Exit(127)
		}
		java = resolved
	}

	argv := javaexec.BuildArgs(java, os.Getenv("JAVA_OPTS"), trusted)

	if err := syscall.Exec(java, argv, os.Environ()); err != nil {
		fmt.Fprintf(os.Stderr, "javaexec: failed to exec %s: %v\n", java, err)
		os.Exit(126)
	}
}
