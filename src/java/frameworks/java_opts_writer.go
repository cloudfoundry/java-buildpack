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
# Normalize to single line: YAML block scalars (>) may introduce newlines; Windows-edited
# manifests may use CRLF (\r\n). Strip \r first, then convert \n to spaces.
# Do not use xargs — it strips quotes and backslashes.
USER_JAVA_OPTS=$(printf '%%s' "$JAVA_OPTS" | tr -d '\r' | tr '\n' ' ')

# Start building new JAVA_OPTS
JAVA_OPTS=""

# Expand $VAR and ${VAR} references in a string using only bash builtins.
# Unlike eval, this NEVER executes command substitutions ($(...) or backticks);
# only environment-variable references are expanded. It is also dependency-free
# (envsubst from gettext-base is not available on the cflinuxfs stacks).
# Expansion is single-pass: substituted values are not re-scanned for further
# references, matching the previous eval-based behavior.
_expand_env_vars() {
    local s="$1" out="" name
    while [[ "$s" =~ ^([^$]*)\$(\{([A-Za-z_][A-Za-z0-9_]*)\}|([A-Za-z_][A-Za-z0-9_]*))? ]]; do
        out+="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[3]}${BASH_REMATCH[4]}"
        if [ -n "$name" ]; then
            out+="${!name}"
        else
            out+='$'
        fi
        s="${s#"${BASH_REMATCH[0]}"}"
    done
    out+="$s"
    printf '%%s' "$out"
}

# The buildpack itself emits the literal command substitution $(nproc) in its
# base JAVA_OPTS (e.g. -XX:ActiveProcessorCount=$(nproc)). The pure-bash
# expander deliberately does not execute command substitutions, so resolve this
# single known, trusted token here by computing the processor count once and
# substituting it literally below. All other command substitutions remain
# literal (and therefore inert).
_nproc_count="$(nproc 2>/dev/null || echo 1)"
# Backtick char, computed here because this script lives inside a Go raw string.
_backtick="$(printf '\140')"
# Placeholder for \$ escape sequences (Ruby buildpack parity: \$VAR → literal $VAR).
_escaped_dollar_placeholder='__JAVA_OPTS_ESCAPED_DOLLAR__'
_dollar='$'

# Expand $VAR / ${VAR} references in user JAVA_OPTS (e.g. $PWD, $HOME), matching
# pre-eval behaviour. \$VAR is treated as a literal $ (not expanded), matching the
# Ruby buildpack's eval-based behaviour where \$ suppressed variable expansion.
# Command substitutions are still not executed.
USER_JAVA_OPTS="${USER_JAVA_OPTS//\\\$/$_escaped_dollar_placeholder}"
USER_JAVA_OPTS=$(_expand_env_vars "$USER_JAVA_OPTS")
USER_JAVA_OPTS="${USER_JAVA_OPTS//$_escaped_dollar_placeholder/$_dollar}"

# Warn if any command substitution remains in user JAVA_OPTS. It will be
# passed literally to the JVM — command substitutions are never executed.
# Show only the offending token, not the full value (which may be long or contain secrets).
case "$USER_JAVA_OPTS" in
    *'$('*)
        _warn_match="${USER_JAVA_OPTS#*'$('}"
        _warn_match="\$(${_warn_match%%%%')'*})"
        echo "WARNING: JAVA_OPTS contains command substitution; it will NOT be executed and will be passed literally to the JVM. Matching: ${_warn_match}" >&2
        ;;
    *"$_backtick"*)
        _warn_match="${USER_JAVA_OPTS#*"$_backtick"}"
        _warn_match="${_backtick}${_warn_match%%%%"$_backtick"*}${_backtick}"
        echo "WARNING: JAVA_OPTS contains command substitution (backtick); it will NOT be executed and will be passed literally to the JVM. Matching: ${_warn_match}" >&2
        ;;
esac

# Escape replacement-special chars once; these values are loop-invariant.
# USER_JAVA_OPTS is injected via string-split below (not ${//}) — bash 4.x and 5.x
# treat '\\' in replacement strings differently, corrupting backslashes.
_escaped_deps_dir="${DEPS_DIR//\\/\\\\}"
_escaped_deps_dir="${_escaped_deps_dir//&/\\&}"
_escaped_home="${HOME//\\/\\\\}"
_escaped_home="${_escaped_home//&/\\&}"
_user_java_opts_placeholder='__JAVA_OPTS_BUILDPACK_PLACEHOLDER__'

if [ -d "$DEPS_DIR/%s/java_opts" ]; then
    for opts_file in "$DEPS_DIR/%s/java_opts"/*.opts; do
        if [ -f "$opts_file" ]; then
            # Read content and expand runtime variables
            opts_content=$(< "$opts_file")

            # Shield \$ from expansion so buildpack authors can write \$VAR to pass
            # a literal $VAR to the JVM (Ruby buildpack parity).
            opts_content="${opts_content//\\\$/$_escaped_dollar_placeholder}"

            # Expand $DEPS_DIR and $HOME using bash parameter expansion.
            # In ${var//pattern/repl}, '&' and '\' are special in replacement strings,
            # so escape them first to preserve literal path contents.
            opts_content="${opts_content//\$DEPS_DIR/$_escaped_deps_dir}"
            opts_content="${opts_content//\$HOME/$_escaped_home}"

            # Resolve the trusted $(nproc) token to the computed processor count.
            opts_content="${opts_content//\$\(nproc\)/$_nproc_count}"

            # Shield $JAVA_OPTS from expansion: replace with a placeholder first,
            # then substitute the actual value AFTER expansion so that quotes and
            # backslashes in the user-provided JAVA_OPTS are never reinterpreted.
            opts_content="${opts_content//\$JAVA_OPTS/$_user_java_opts_placeholder}"

            # Expand any remaining environment variables in opts content.
            # Use a pure-bash expander instead of eval so that command
            # substitutions like $(...) or backticks in .opts content are
            # NOT executed — only $VAR / ${VAR} references are expanded.
            opts_content=$(_expand_env_vars "$opts_content")

            # Restore \$ escapes to literal $ now that expansion is done.
            opts_content="${opts_content//$_escaped_dollar_placeholder/$_dollar}"

            # Defense-in-depth: the buildpack resolves its only known command
            # substitution ($(nproc)) above. Any remaining $(...) or backtick at
            # this point is an unresolved buildpack-emitted substitution (the
            # user's JAVA_OPTS is still a placeholder here) and would reach the
            # JVM literally. Warn so such a regression is caught instead of
            # silently producing a broken argument.
            case "$opts_content" in
                *'$('*|*"$_backtick"*)
                    echo "WARNING: unresolved command substitution in $opts_file; it will be passed to the JVM literally: $opts_content" >&2
                    ;;
            esac

            # Restore USER_JAVA_OPTS via string-split, not ${//}: bash 4.x and 5.x
            # treat '\\' in replacement strings differently, corrupting backslashes.
            # %%%% / # are pure string ops — no special-char interpretation, any bash.
            # Pre-count occurrences so the loop is bounded even if USER_JAVA_OPTS
            # itself contained the placeholder string (infinite-loop defence).
            # Counting uses empty replacement — no backslash in replacement, safe.
            # Handles multiple occurrences (e.g. user config "$JAVA_OPTS -Xmx512m"
            # with from_environment:true produces "$JAVA_OPTS -Xmx512m $JAVA_OPTS").
            _stripped="${opts_content//"$_user_java_opts_placeholder"/}"
            _placeholder_count=$(( (${#opts_content} - ${#_stripped}) / ${#_user_java_opts_placeholder} ))
            for (( _i=0; _i<_placeholder_count; _i++ )); do
                _before="${opts_content%%%%"$_user_java_opts_placeholder"*}"
                _after="${opts_content#*"$_user_java_opts_placeholder"}"
                opts_content="${_before}${USER_JAVA_OPTS}${_after}"
            done
            
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
