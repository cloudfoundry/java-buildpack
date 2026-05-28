#!/bin/bash

set -e
set -u
set -o pipefail

function main() {
  if [[ "${CF_STACK:-}" != "cflinuxfs4" && "${CF_STACK:-}" != "cflinuxfs5" ]]; then
    echo "       **ERROR** Unsupported stack"
    echo "                 See https://docs.cloudfoundry.org/devguide/deploy-apps/stacks.html for more info"
    exit 1
  fi

  local version expected_sha dir
  version="1.25.10"
  expected_sha_cflinuxfs4="a1d6fbc0293b4de0f122f55df4af8689b294ef7a9d749b9f24e761deef33464e"
  expected_sha_cflinuxfs5="ae729ea414d69b4c3a4757f772d6b4f4c3a1a6213c1d0d7e3267139cef708327"
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
