#!/bin/bash
# Tests the failed-test retry logic in scripts/integration.sh with a stubbed `go`.
set -euo pipefail

ROOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=integration.sh
source "${ROOTDIR}/scripts/integration.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

failures=0

function check() {
  local name="${1}" expected="${2}" actual="${3}"
  if [[ "${expected}" == "${actual}" ]]; then
    echo "PASS: ${name}"
  else
    echo "FAIL: ${name} (expected '${expected}', got '${actual}')"
    failures=$((failures + 1))
  fi
}

# Stub: prints the pass line for the retried test when GO_STUB_PASS is set; counts invocations.
# GO_STUB_NOMATCH simulates a -run pattern that matches nothing: exit 0 without running any test.
function go() {
  echo "x" >>"${tmpdir}/go-calls"
  if [[ "${GO_STUB_NOMATCH:-false}" == "true" ]]; then
    echo "testing: warning: no tests to run"
    return 0
  fi
  if [[ "${GO_STUB_PASS:-false}" == "true" ]]; then
    echo "    --- PASS: TestIntegration/integration/Flaky_one (0.00s)"
    return 0
  fi
  echo "    --- FAIL: TestIntegration/integration/Flaky_one (0.00s)"
  return 1
}

function go_calls() {
  if [[ -f "${tmpdir}/go-calls" ]]; then wc -l <"${tmpdir}/go-calls" | tr -d ' '; else echo 0; fi
}

function run_retry() {
  local log="${1}" rc=0
  rm -f "${tmpdir}/go-calls"
  specs::retry_failed "${log}" ./pkg >/dev/null 2>&1 || rc=$?
  echo "${rc}"
}

subtest_log="${tmpdir}/subtest.log"
cat >"${subtest_log}" <<'EOF'
--- FAIL: TestIntegration (1.00s)
    --- FAIL: TestIntegration/integration (1.00s)
        --- FAIL: TestIntegration/integration/Flaky_one (1.00s)
        --- PASS: TestIntegration/integration/Stable (1.00s)
FAIL
EOF

failed="$(specs::failed_tests "${subtest_log}")"
check "failed_tests returns only the failed leaf" "TestIntegration/integration/Flaky_one" "${failed}"

check "run_pattern anchors each name element" \
  '^TestIntegration$/^integration$/^Flaky_one$' \
  "$(specs::run_pattern "TestIntegration/integration/Flaky_one")"

check "run_pattern escapes regex metacharacters" \
  '^TestIntegration$/^a\.b\(c\)$' \
  "$(specs::run_pattern "TestIntegration/a.b(c)")"

GO_STUB_PASS=true
check "flaky test passing on retry succeeds" "0" "$(run_retry "${subtest_log}")"

GO_STUB_PASS=false
check "test failing on every retry fails" "1" "$(run_retry "${subtest_log}")"
check "each failing test is retried INTEGRATION_RETRIES times" "2" "$(go_calls)"

GO_STUB_NOMATCH=true
check "retry matching no test is not counted as passed" "1" "$(run_retry "${subtest_log}")"
GO_STUB_NOMATCH=false

INTEGRATION_RETRIES=0
GO_STUB_PASS=true
check "retries disabled fails without rerunning" "1" "$(run_retry "${subtest_log}")"
check "retries disabled never calls go" "0" "$(go_calls)"
unset INTEGRATION_RETRIES

root_log="${tmpdir}/root.log"
printf -- '--- FAIL: TestIntegration (1.00s)\nFAIL\n' >"${root_log}"
check "root-only failure is not retried" "1" "$(run_retry "${root_log}")"
check "root-only failure never calls go" "0" "$(go_calls)"

panic_log="${tmpdir}/panic.log"
{ echo "panic: boom"; cat "${subtest_log}"; } >"${panic_log}"
check "panic is not retried" "1" "$(run_retry "${panic_log}")"

build_log="${tmpdir}/build.log"
{ cat "${subtest_log}"; echo "FAIL	example.com/integration [build failed]"; } >"${build_log}"
check "build failure is not retried" "1" "$(run_retry "${build_log}")"

nosummary_log="${tmpdir}/nosummary.log"
printf -- '        --- FAIL: TestIntegration/integration/Flaky_one (1.00s)\n' >"${nosummary_log}"
check "log without the TestIntegration summary is not retried" "1" "$(run_retry "${nosummary_log}")"

if [[ "${failures}" -gt 0 ]]; then
  echo "${failures} check(s) failed"
  exit 1
fi
echo "All checks passed"
