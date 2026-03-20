#!/usr/bin/env bash

set -e
set -u
set -o pipefail

# shellcheck source=SCRIPTDIR/print.sh
source "$(dirname "${BASH_SOURCE[0]}")/print.sh"

function util::tools::path::export() {
  local dir
  dir="${1}"

  if ! echo "${PATH}" | grep -q "${dir}"; then
    PATH="${dir}:$PATH"
    export PATH
  fi
}

function util::tools::ginkgo::install() {
  local dir
  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      --directory)
        dir="${2}"
        shift 2
        ;;

      *)
        util::print::error "unknown argument \"${1}\""
    esac
  done

  mkdir -p "${dir}"
  util::tools::path::export "${dir}"

  if [[ ! -f "${dir}/ginkgo" ]]; then
    util::print::title "Installing ginkgo"

    pushd /tmp > /dev/null || return
      GOBIN="${dir}" \
        go install \
          github.com/onsi/ginkgo/v2/ginkgo@latest
    popd > /dev/null || return
  fi
}

function util::tools::buildpack-packager::install() {
  local dir
  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      --directory)
        dir="${2}"
        shift 2
        ;;

      *)
        util::print::error "unknown argument \"${1}\""
    esac
  done

  mkdir -p "${dir}"
  util::tools::path::export "${dir}"

  if [[ ! -f "${dir}/buildpack-packager" ]]; then
    util::print::title "Installing buildpack-packager"

    pushd /tmp > /dev/null || return
      GOBIN="${dir}" \
        go install \
          github.com/cloudfoundry/libbuildpack/packager/buildpack-packager@latest
    popd > /dev/null || return
  fi
}

function util::tools::jq::install() {
  local dir
  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      --directory)
        dir="${2}"
        shift 2
        ;;

      *)
        util::print::error "unknown argument \"${1}\""
    esac
  done

  mkdir -p "${dir}"
  util::tools::path::export "${dir}"

  local os
  case "$(uname)" in
    "Darwin")
      os="osx-amd64"
      ;;

    "Linux")
      os="linux64"
      ;;

    *)
      echo "Unknown OS \"$(uname)\""
      exit 1
  esac

  if [[ ! -f "${dir}/jq" ]]; then
    util::print::title "Installing jq"

    curl "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-${os}" \
      --silent \
      --location \
      --output "${dir}/jq"
    chmod +x "${dir}/jq"
  fi
}

function util::tools::cf::install() {
  local dir
  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      --directory)
        dir="${2}"
        shift 2
        ;;

      *)
        util::print::error "unknown argument \"${1}\""
    esac
  done

  mkdir -p "${dir}"
  util::tools::path::export "${dir}"

  local os
  case "$(uname)" in
    "Darwin")
      os="macosx64"
      ;;

    "Linux")
      os="linux64"
      ;;

    *)
      echo "Unknown OS \"$(uname)\""
      exit 1
  esac

  if [[ ! -f "${dir}/cf" ]]; then
    util::print::title "Installing cf"

    curl "https://packages.cloudfoundry.org/stable?release=${os}-binary&version=6.49.0&source=github-rel" \
      --silent \
      --location \
      --output /tmp/cf.tar.gz
    tar -xzf /tmp/cf.tar.gz -C "${dir}" cf
    rm /tmp/cf.tar.gz
  fi
}
