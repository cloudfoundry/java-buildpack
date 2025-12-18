package frameworks

import (
	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"fmt"
	"os"
	"path/filepath"
)

// writeJavaOptsFile writes JAVA_OPTS to a numbered .opts file for centralized assembly
//
// Priority determines execution order (lower numbers run first):
//   - 05: JRE base options
//   - 11: AppDynamics Agent
//   - 12: AspectJ Weaver Agent
//   - 13: Azure Application Insights Agent
//   - 14: Checkmarx IAST Agent
//   - 17: Container Security Provider
//   - 18: Contrast Security Agent
//   - 19: Datadog Java Agent (changed from 18 to avoid collision)
//   - 20: Debug Framework, Elastic APM Agent
//   - 21: Google Stackdriver Debugger
//   - 22: Google Stackdriver Profiler
//   - 26: JaCoCo Agent
//   - 27: Introscope Agent
//   - 29: JMX Framework
//   - 30: JProfiler Profiler
//   - 31: JRebel Agent
//   - 32: Luna Security Provider
//   - 35: New Relic Agent
//   - 36: OpenTelemetry Javaagent
//   - 37: Riverbed AppInternals Agent
//   - 38: ProtectApp Security Provider
//   - 39: Sealights Agent
//   - 40: Seeker Security Provider
//   - 41: SkyWalking Agent
//   - 42: Splunk OTEL Java Agent
//   - 45: YourKit Profiler
//   - 46: Takipi Agent
//   - 99: User JAVA_OPTS (always last)
//
// At runtime, profile.d/00_java_opts.sh reads all .opts files in order and assembles JAVA_OPTS
func writeJavaOptsFile(ctx *common.Context, priority int, name string, javaOpts string) error {
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
func CreateJavaOptsAssemblyScript(ctx *common.Context) error {
	assemblyScript := `#!/bin/bash
# Centralized JAVA_OPTS Assembly
# Reads all .opts files from $DEPS_DIR/0/java_opts/ in numerical order
# and assembles them into a single JAVA_OPTS environment variable
# Expands runtime variables like $DEPS_DIR, $HOME, $JAVA_OPTS, and all other environment variables

# Save original JAVA_OPTS from environment (user-provided)
USER_JAVA_OPTS="$JAVA_OPTS"

# Start building new JAVA_OPTS
JAVA_OPTS=""

if [ -d "$DEPS_DIR/0/java_opts" ]; then
    for opts_file in "$DEPS_DIR/0/java_opts"/*.opts; do
        if [ -f "$opts_file" ]; then
            # Read content and expand runtime variables
            opts_content=$(cat "$opts_file")
            
            # First, expand special variables that need specific handling
            # Expand $DEPS_DIR variable
            opts_content=$(echo "$opts_content" | sed "s|\$DEPS_DIR|$DEPS_DIR|g")
            
            # Expand $HOME variable (for app-provided JARs like AspectJ)
            opts_content=$(echo "$opts_content" | sed "s|\$HOME|$HOME|g")
            
            # Expand $JAVA_OPTS to the saved USER_JAVA_OPTS value (not the loop's current JAVA_OPTS)
            opts_content=$(echo "$opts_content" | sed "s|\$JAVA_OPTS|$USER_JAVA_OPTS|g")
            
            # Now expand all remaining environment variables using eval with proper escaping
            # This mimics Ruby buildpack behavior where shell naturally expands variables
            # Use eval in a subshell to safely expand variables without executing commands
            opts_content=$(eval "echo \"$opts_content\"")
            
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
