package frameworks

import (
	"fmt"
	"os"
	"path/filepath"
)

// writeJavaOptsFile writes JAVA_OPTS to a numbered .opts file for centralized assembly
// Priority determines execution order (lower numbers run first):
//   - JRE base options: 05
//   - Container Security Provider: 17 (Ruby line 51)
//   - Debug: 20 (Ruby line 54)
//   - JMX: 29 (Ruby line 63)
//   - JRebel: 31 (Ruby line 65)
//   - User JAVA_OPTS: 99 (Ruby line 82, always last)
//
// At runtime, profile.d/00_java_opts.sh reads all .opts files in order and assembles JAVA_OPTS
func writeJavaOptsFile(ctx *Context, priority int, name string, javaOpts string) error {
	// Create java_opts directory in deps
	optsDir := filepath.Join(ctx.Stager.DepDir(), "java_opts")
	if err := os.MkdirAll(optsDir, 0755); err != nil {
		return fmt.Errorf("failed to create java_opts directory: %w", err)
	}

	// Write .opts file with priority prefix (e.g., 17_container_security.opts)
	filename := fmt.Sprintf("%02d_%s.opts", priority, name)
	optsFile := filepath.Join(optsDir, filename)

	if err := os.WriteFile(optsFile, []byte(javaOpts), 0644); err != nil {
		return fmt.Errorf("failed to write %s: %w", filename, err)
	}

	ctx.Log.Debug("Wrote JAVA_OPTS to %s (priority %d)", filename, priority)
	return nil
}

// CreateJavaOptsAssemblyScript creates the centralized profile.d script that assembles all JAVA_OPTS
// This should be called ONCE during finalization (by the finalize coordinator)
func CreateJavaOptsAssemblyScript(ctx *Context) error {
	assemblyScript := `#!/bin/bash
# Centralized JAVA_OPTS Assembly
# Reads all .opts files from $DEPS_DIR/0/java_opts/ in numerical order
# and assembles them into a single JAVA_OPTS environment variable
# Expands runtime variables like $DEPS_DIR, $HOME, and $JAVA_OPTS

# Save original JAVA_OPTS from environment (user-provided)
USER_JAVA_OPTS="$JAVA_OPTS"

# Start building new JAVA_OPTS
JAVA_OPTS=""

if [ -d "$DEPS_DIR/0/java_opts" ]; then
    for opts_file in "$DEPS_DIR/0/java_opts"/*.opts; do
        if [ -f "$opts_file" ]; then
            # Read content and expand runtime variables
            opts_content=$(cat "$opts_file")
            
            # Expand $DEPS_DIR variable
            opts_content=$(echo "$opts_content" | sed "s|\$DEPS_DIR|$DEPS_DIR|g")
            
            # Expand $HOME variable (for app-provided JARs like AspectJ)
            opts_content=$(echo "$opts_content" | sed "s|\$HOME|$HOME|g")
            
            # Now expand $JAVA_OPTS to the saved USER_JAVA_OPTS value (not the loop's current JAVA_OPTS)
            opts_content=$(echo "$opts_content" | sed "s|\$JAVA_OPTS|$USER_JAVA_OPTS|g")
            
            if [ -n "$opts_content" ]; then
                JAVA_OPTS="$JAVA_OPTS $opts_content"
            fi
        fi
    done
fi

# Trim leading/trailing whitespace
JAVA_OPTS=$(echo "$JAVA_OPTS" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

export JAVA_OPTS
`

	if err := ctx.Stager.WriteProfileD("00_java_opts.sh", assemblyScript); err != nil {
		return fmt.Errorf("failed to write 00_java_opts.sh: %w", err)
	}

	ctx.Log.Debug("Created centralized JAVA_OPTS assembly script: profile.d/00_java_opts.sh")
	return nil
}
