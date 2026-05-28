#!/bin/bash

set -e
set -u
set -o pipefail

function main() {
  if [[ "${CF_STACK:-}" != "cflinuxfs3" && "${CF_STACK:-}" != "cflinuxfs4" && "${CF_STACK:-}" != "cflinuxfs5" ]]; then
    echo "       **ERROR** Unsupported stack"
    echo "                 See https://docs.cloudfoundry.org/devguide/deploy-apps/stacks.html for more info"
    exit 1
  fi

  local version expected_sha dir
  version="1.24.13"
  expected_sha_cflinuxfs4="7ed0876f713f6add32f07c1d82e7ea026b07995c084492c36e6fa27b37d58291"
  expected_sha_cflinuxfs5="f8361b031b0940ade20ecd61c8e9876be6153f86fa675c4a5befaf5ce69e3ee5"
  if [[ "${CF_STACK}" == "cflinuxfs4" ]]; then
    expected_sha="${expected_sha_cflinuxfs4}"
  elif [[ "${CF_STACK}" == "cflinuxfs5" ]]; then
    expected_sha="${expected_sha_cflinuxfs5}"
  else
    echo "       **ERROR** No SHA defined for stack: ${CF_STACK}"
    exit 1
  fi
  dir="/tmp/go${version}"

  mkdir -p "${dir}"

  if [[ ! -f "${dir}/bin/go" ]]; then
    local url
    url="https://buildpacks.cloudfoundry.org/dependencies/go/go_${version}_linux_x64_${CF_STACK}_${expected_sha:0:8}.tgz"
    # url="https://buildpacks.cloudfoundry.org/dependencies/go/go_${version}_linux_x64_cflinuxfs3_${expected_sha:0:8}.tgz"

    echo "-----> Download go ${version}"
    curl "${url}" \
      --silent \
      --location \
      --retry 15 \
      --retry-delay 2 \
      --output "/tmp/go.tgz"

    local sha
    sha="$(shasum -a 256 /tmp/go.tgz | cut -d ' ' -f 1)"

    if [[ "${sha}" != "${expected_sha}" ]]; then
      echo "       **ERROR** SHA256 mismatch: got ${sha}, expected ${expected_sha}"
      exit 1
    fi

    tar xzf "/tmp/go.tgz" -C "${dir}"
    rm "/tmp/go.tgz"
  fi

  if [[ ! -f "${dir}/bin/go" ]]; then
    echo "       **ERROR** Could not download go"
    exit 1
  fi

  GoInstallDir="${dir}"
  export GoInstallDir
}

main "${@:-}"
