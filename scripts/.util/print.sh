#!/usr/bin/env bash

set -eu
set -o pipefail

function util::print::title() {
  local blue reset message
  blue="\033[0;34m"
  reset="\033[0;39m"
  message="${1}"

  echo -e "\n${blue}${message}${reset}" >&2
}

function util::print::info() {
  local message
  message="${1}"

  echo -e "${message}" >&2
}

function util::print::error() {
  local message red reset
  message="${1}"
  red="\033[0;31m"
  reset="\033[0;39m"

  echo -e "${red}${message}${reset}" >&2
  exit 1
}

function util::print::success() {
  local message green reset
  message="${1}"
  green="\033[0;32m"
  reset="\033[0;39m"

  echo -e "${green}${message}${reset}" >&2
  exitcode="${2:-0}"
  exit "${exitcode}"
}

function util::print::warn() {
  local message yellow reset
  message="${1}"
  yellow="\033[0;33m"
  reset="\033[0;39m"

  echo -e "${yellow}${message}${reset}" >&2
  exit 0
}
