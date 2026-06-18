#!/bin/bash
# Manual smoke test for the bin/finalize source/git buildpack path.
# Simulates what bin/finalize does: build javaexec into a temp dir and pass
# the path via JAVAEXEC_BINARY_PATH. Verifies the binary builds, that
# InstallJavaexecLauncher picks up the override, and that javaexec tokenizes
# JAVA_OPTS correctly when actually invoked.
set -euo pipefail

BUILDPACK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$BUILDPACK_DIR"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "==> [1/4] Build javaexec from source (as bin/finalize now does)"
go build -mod=vendor -o "$tmpdir/javaexec" ./src/java/javaexec/cli
echo "    OK: $tmpdir/javaexec ($(wc -c < "$tmpdir/javaexec") bytes)"

echo ""
echo "==> [2/4] Build finalize from source"
go build -mod=vendor -o "$tmpdir/finalize" ./src/java/finalize/cli
echo "    OK: $tmpdir/finalize"

echo ""
echo "==> [3/4] Unit tests: InstallJavaexecLauncher with JAVAEXEC_BINARY_PATH override"
go test ./src/java/finalize/ -count=1 -v -run "javaexec launcher" 2>&1 | grep -E "PASS|FAIL|RUN|---"

echo ""
echo "==> [4/4] Tokenization smoke test: run javaexec with a fake java binary"

# Fake java: prints each received argument on its own line.
cat > "$tmpdir/fake-java" << 'EOF'
#!/bin/bash
printf '%s\n' "$@"
EOF
chmod +x "$tmpdir/fake-java"

# Quoted value with spaces → one token; cron expr with * → literal; $(...) → not executed.
JAVA_OPTS='-Dfoo="bar baz" -DcronSched="0 */7 * * * *" -Dwhere=$(hostname)' \
  "$tmpdir/javaexec" "$tmpdir/fake-java" -jar app.jar 2>/dev/null > "$tmpdir/actual.txt"

expected="-Dfoo=bar baz
-DcronSched=0 */7 * * * *
-Dwhere=\$(hostname)
-jar
app.jar"

actual=$(cat "$tmpdir/actual.txt")

if [ "$actual" = "$expected" ]; then
  echo "    OK: all tokens correct"
else
  echo "    FAIL: unexpected output"
  echo "    expected:"
  printf '%s\n' "$expected" | sed 's/^/      /'
  echo "    got:"
  printf '%s\n' "$actual" | sed 's/^/      /'
  exit 1
fi

echo ""
echo "PASS: source/git buildpack path works."
echo "      bin/finalize builds javaexec and passes it via JAVAEXEC_BINARY_PATH."
echo "      javaexec tokenizes JAVA_OPTS correctly without shell execution."
