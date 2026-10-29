#!/usr/bin/env bash

set -euo pipefail

ROOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOTDIR

# shellcheck source=SCRIPTDIR/.util/print.sh
source "${ROOTDIR}/scripts/.util/print.sh"

# shellcheck source=SCRIPTDIR/.util/tools.sh
source "${ROOTDIR}/scripts/.util/tools.sh"

function usage() {
  cat <<-USAGE
integration.sh --github-token <token> [OPTIONS]

Runs the integration tests.

OPTIONS
  --help                         -h  prints the command usage
  --github-token <token>             GitHub token to use when making API requests
  --platform <cf|docker>             Switchblade platform to execute the tests against (default: cf)
  --cached <true|false>              Run cached/offline tests (default: false)
  --parallel <true|false>            Run tests in parallel (default: false)
  --stack <stack>                    Stack to use for tests (default: cflinuxfs4)
  --keep-failed-containers           Preserve failed test containers for debugging (default: false)

ENVIRONMENT
  INTEGRATION_RETRIES                Times to rerun each failed test on its own after a full run
                                     fails, so a transient failure does not cost a full run.
                                     0 disables it (default: 2)

EXAMPLES
  # Serial mode
  ./scripts/integration.sh --platform docker

  # Parallel mode (uses GOMAXPROCS=2)
  ./scripts/integration.sh --platform docker --parallel true

  # Keep failed containers for debugging
  ./scripts/integration.sh --platform docker --keep-failed-containers
USAGE
}

function main() {
  local src stack platform token cached parallel keep_failed
  src="${ROOTDIR}/src/java/integration"
  stack="${CF_STACK:-cflinuxfs4}"
  platform="cf"
  cached="false"
  parallel="false"
  keep_failed="false"
  token="${GITHUB_TOKEN:-}"

  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      --platform)
        platform="${2}"
        shift 2
        ;;

      --github-token)
        token="${2}"
        shift 2
        ;;

      --cached)
        cached="${2}"
        shift 2
        ;;

      --parallel)
        parallel="${2}"
        shift 2
        ;;

      --stack)
        stack="${2}"
        shift 2
        ;;

      --keep-failed-containers)
        keep_failed="true"
        shift 1
        ;;

      --help|-h)
        shift 1
        usage
        exit 0
        ;;

      "")
        # skip if the argument is empty
        shift 1
        ;;

      *)
        echo "ERROR: unknown argument \"${1}\""
        usage
        exit 1
        ;;
    esac
  done

  echo "=== Java Buildpack Integration Tests ==="
  echo "Platform:           ${platform}"
  echo "Stack:              ${stack}"
  echo "Cached:             ${cached}"
  echo "Parallel:           ${parallel}"
  echo "Keep Failed:        ${keep_failed}"
  echo ""

  specs::run "${cached}" "${parallel}" "${stack}" "${platform}" "${token}" "${keep_failed}"
}

function specs::run() {
  local cached parallel stack platform token keep_failed
  cached="${1}"
  parallel="${2}"
  stack="${3}"
  platform="${4}"
  token="${5}"
  keep_failed="${6}"

  local nodes cached_flag serial_flag platform_flag stack_flag token_flag keep_failed_flag
  cached_flag="--cached=${cached}"
  serial_flag="--serial=true"
  platform_flag="--platform=${platform}"
  stack_flag="--stack=${stack}"
  token_flag="--github-token=${token}"
  keep_failed_flag="--keep-failed-containers=${keep_failed}"
  nodes=1

  if [[ "${parallel}" == "true" ]]; then
    nodes=3
    serial_flag=""
  fi

  cd "${ROOTDIR}"
  go mod download

  local buildpack_file
  buildpack_file="$(buildpack::package "1.2.3" "${cached}" "${stack}")"

  local log
  log="$(mktemp)"

  local -a go_test_args
  go_test_args=(
    "${ROOTDIR}/src/integration"
    ${cached_flag}
    ${platform_flag}
    ${token_flag}
    ${stack_flag}
    ${serial_flag}
    ${keep_failed_flag}
  )

  export CF_STACK="${stack}"
  export BUILDPACK_FILE="${BUILDPACK_FILE:-"${buildpack_file}"}"
  export GOMAXPROCS="${GOMAXPROCS:-"${nodes}"}"

  local status=0
  if go test -count=1 -timeout=0 -mod vendor -v "${go_test_args[@]}" 2>&1 | tee "${log}"; then
    rm -f "${log}"
    return 0
  fi

  specs::retry_failed "${log}" "${go_test_args[@]}" || status=$?
  rm -f "${log}"
  return "${status}"
}

# Reruns only the tests that failed, so a transient failure (for example a Cloud Controller 500)
# does not cost a full run. Set INTEGRATION_RETRIES=0 to disable.
function specs::retry_failed() {
  local log="${1}"
  shift

  local retries="${INTEGRATION_RETRIES:-2}"

  # A crash, build failure or panic can leave tests unrun, so only trust the failed test list
  # when the run completed normally and printed its summary.
  if [[ "${retries}" -lt 1 ]] ||
    grep -qE '^(panic:|FAIL\s.*\[(build|setup) failed\])' "${log}" ||
    ! grep -qE '^--- FAIL: TestIntegration ' "${log}"; then
    return 1
  fi

  local failed
  failed="$(specs::failed_tests "${log}")"
  if [[ -z "${failed}" ]]; then
    return 1
  fi

  # The root test is a leaf when initialization or teardown fails without a failed subtest.
  # Rerunning it would rerun the whole suite, so leave that to the task-level retry.
  if grep -qx 'TestIntegration' <<<"${failed}"; then
    return 1
  fi

  echo ""
  echo "=== Rerunning failed tests only (up to ${retries} retries each) ==="

  local test attempt recovered still_failing retry_log
  recovered=()
  still_failing=()
  retry_log="$(mktemp)"
  while IFS= read -r test; do
    local passed="false"
    for ((attempt = 1; attempt <= retries; attempt++)); do
      echo "--- Retry ${attempt}/${retries}: ${test}"
      # A pattern that matches nothing also exits 0, so require the test to be reported as passed.
      if go test -count=1 -timeout=0 -mod vendor -v -run "$(specs::run_pattern "${test}")" "$@" 2>&1 | tee "${retry_log}" &&
        grep -qE "^\s*--- PASS: ${test//[^[:alnum:]_\/-]/.} " "${retry_log}"; then
        passed="true"
        break
      fi
    done
    if [[ "${passed}" == "true" ]]; then
      recovered+=("${test}")
    else
      still_failing+=("${test}")
    fi
  done <<<"${failed}"
  rm -f "${retry_log}"

  echo ""
  echo "=== Retry summary ==="
  for test in "${recovered[@]+"${recovered[@]}"}"; do
    echo "PASSED ON RETRY: ${test}"
  done
  for test in "${still_failing[@]+"${still_failing[@]}"}"; do
    echo "STILL FAILING:   ${test}"
  done

  [[ "${#still_failing[@]}" -eq 0 ]]
}

# Prints the full names of the failed leaf tests: failed tests that have no failed subtests.
function specs::failed_tests() {
  local log="${1}"

  grep -E '^\s*--- FAIL: ' "${log}" |
    sed -E 's/^\s*--- FAIL: ([^ ]+) .*/\1/' |
    sort -u |
    awk '
      { names[NR] = $0 }
      END {
        for (i = 1; i <= NR; i++) {
          leaf = 1
          for (j = 1; j <= NR; j++) {
            if (index(names[j], names[i] "/") == 1) { leaf = 0; break }
          }
          if (leaf) print names[i]
        }
      }'
}

# Turns a full test name into an anchored -run pattern, one regular expression per name element.
function specs::run_pattern() {
  local name="${1}" element pattern=""
  local -a elements
  IFS='/' read -ra elements <<<"${name}"
  for element in "${elements[@]}"; do
    element="$(printf '%s' "${element}" | sed -E 's/[][\\.*+?(){}|^$]/\\&/g')"
    pattern+="${pattern:+/}^${element}\$"
  done
  printf '%s' "${pattern}"
}

function buildpack::package() {
  local version cached stack
  version="${1}"
  cached="${2}"
  stack="${3}"

  local name cached_flag
  name="buildpack-${stack}-v${version}-uncached.zip"
  cached_flag=""
  if [[ "${cached}" == "true" ]]; then
    cached_flag="--cached"
    name="buildpack-${stack}-v${version}-cached.zip"
  fi

  local output
  output="$(mktemp -d)/${name}"

  CF_STACK="${stack}" bash "${ROOTDIR}/scripts/package.sh" \
    --version "${version}" \
    --output "${output}" \
    --stack "${stack}" \
    ${cached_flag} > /dev/null

  printf "%s" "${output}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "${@:-}"
fi
