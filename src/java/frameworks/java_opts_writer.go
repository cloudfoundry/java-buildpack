package frameworks

import (
	"fmt"
	"github.com/cloudfoundry/java-buildpack/src/java/common"
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
	// Get the actual buildpack index to support multi-buildpack scenarios
	depsIdx := ctx.Stager.DepsIdx()

	// Build the assembly script with the correct buildpack index
	assemblyScript := fmt.Sprintf(`#!/bin/bash
# Centralized JAVA_OPTS Assembly
# Reads all .opts files from $DEPS_DIR/%s/java_opts/ in numerical order
# and assembles them into a single JAVA_OPTS environment variable
# Expands runtime variables like $DEPS_DIR, $HOME, $JAVA_OPTS, and all other environment variables

# Save original JAVA_OPTS from environment (user-provided)
# Normalize to single line: YAML block scalars (>) may introduce newlines
# Only convert newlines to spaces — do not use xargs which strips quotes and backslashes
USER_JAVA_OPTS=$(echo "$JAVA_OPTS" | tr '\n' ' ')

# Start building new JAVA_OPTS
JAVA_OPTS=""

if [ -d "$DEPS_DIR/%s/java_opts" ]; then
    for opts_file in "$DEPS_DIR/%s/java_opts"/*.opts; do
        if [ -f "$opts_file" ]; then
            # Read content and expand runtime variables
            opts_content=$(cat "$opts_file")
            
            # Expand $DEPS_DIR and $HOME using bash parameter expansion.
            # sed-based substitution breaks when these values contain the sed delimiter (|),
            # backslashes, ampersands, or newlines — all valid in JAVA_OPTS and paths.
            opts_content="${opts_content//\$DEPS_DIR/$DEPS_DIR}"
            opts_content="${opts_content//\$HOME/$HOME}"

            # Shield $JAVA_OPTS from eval: replace with a placeholder first,
            # then substitute the actual value AFTER eval so that quotes and
            # backslashes in the user-provided JAVA_OPTS are never exposed to eval.
            _user_java_opts_placeholder='__JAVA_OPTS_BUILDPACK_PLACEHOLDER__'
            opts_content="${opts_content//\$JAVA_OPTS/$_user_java_opts_placeholder}"

            # Expand any remaining environment variables in opts content via eval.
            # Note: eval executes commands, but .opts files are written by the buildpack
            # at staging time and run within the container context.
            # This matches how the Ruby buildpack naturally expanded variables via shell.
            opts_content=$(eval "echo \"$opts_content\"")

            # Now safely substitute JAVA_OPTS after eval (preserves quotes and backslashes)
            opts_content="${opts_content//$_user_java_opts_placeholder/$USER_JAVA_OPTS}"
            
            if [ -n "$opts_content" ]; then
                JAVA_OPTS="$JAVA_OPTS $opts_content"
            fi
        fi
    done
fi

# Trim leading/trailing whitespace
JAVA_OPTS=$(echo "$JAVA_OPTS" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

export JAVA_OPTS
`, depsIdx, depsIdx, depsIdx)

	if err := ctx.Stager.WriteProfileD("00_java_opts.sh", assemblyScript); err != nil {
		return fmt.Errorf("failed to write 00_java_opts.sh: %w", err)
	}

	ctx.Log.Debug("Created centralized JAVA_OPTS assembly script: profile.d/00_java_opts.sh")
	return nil
}
