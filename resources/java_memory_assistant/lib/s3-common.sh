#!/usr/bin/env bash
# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Common functions for s3-bash4 commands
# (c) 2015 Chi Vinh Le <cvl@winged.kiwi>

# Constants
readonly VERSION="0.0.1"

# Exit codes
readonly INVALID_USAGE_EXIT_CODE=1
readonly INVALID_USER_DATA_EXIT_CODE=2
readonly INVALID_ENVIRONMENT_EXIT_CODE=3

##
# Write error to stderr
# Arguments:
#   $1 string to output
##
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] Error: $@" >&2
}


##
# Display version and exit
##
showVersionAndExit() {
  printf "$VERSION\n"
  exit
}

##
# Helper for parsing the command line.
##
assertArgument() {
  if [[ $# -lt 2 ]]; then
    err "Option $1 needs an argument."
    exit $INVALID_USAGE_EXIT_CODE
  fi
}

##
# Asserts given resource path
# Arguments:
#   $1 string resource path
##
assertResourcePath() {
  if [[ $1 = !(/*) ]]; then
    err "Resource should start with / e.g. /bucket/file.ext"
    exit $INVALID_USAGE_EXIT_CODE
  fi
}

##
# Asserts given file exists.
# Arguments:
#   $1 string file path
##
assertFileExists() {
  if [[ ! -f $1 ]]; then
    err "$1 file doesn't exists"
    exit $INVALID_USER_DATA_EXIT_CODE
  fi
}

##
# Check for valid environment. Exit if invalid.
##
checkEnvironment()
{
  programs=(openssl curl printf echo sed awk od date shasum pwd dirname)
  for program in "${programs[@]}"; do
    if [ ! -x "$(which $program)" ]; then
      err "$program is required to run"
      exit $INVALID_ENVIRONMENT_EXIT_CODE
    fi
  done
}

##
# Reads, validates and return aws secret stored in a file
# Arguments:
#   $1 path to secret file
# Output:
#   string AWS secret
##
processAWSSecretFile() {
  local errStr="The Amazon AWS secret key must be 40 bytes long. Make sure that there is no carriage return at the end of line."
  if ! [[ -f $1 ]]; then
    err "The file $1 does not exist."
    exit $INVALID_USER_DATA_EXIT_CODE
  fi

  # limit file size to max 41 characters. 40 + potential null terminating character.
  local fileSize="$(ls -l "$1" | awk '{ print $5 }')"
  if [[ $fileSize -gt 41 ]]; then
    err $errStr
    exit $INVALID_USER_DATA_EXIT_CODE
  fi

  secret=$(<$1)
  # exact string size should be 40.
  if [[ ${#secret} != 40 ]]; then
    err $errStr
    exit $INVALID_USER_DATA_EXIT_CODE
  fi
  echo $secret
}

##
# Convert string to hex with max line size of 256
# Arguments:
#   $1 string to convert
# Returns:
#   string hex
##
hex256() {
  printf "$1" | od -A n -t x1 | sed ':a;N;$!ba;s/[\n ]//g'
}

##
# Calculate sha256 hash
# Arguments:
#   $1 string to hash
# Returns:
#   string hash
##
sha256Hash() {
  local output=$(printf "$1" | shasum -a 256)
  echo "${output%% *}"
}

##
# Calculate sha256 hash of file
# Arguments:
#   $1 file path
# Returns:
#   string hash
##
sha256HashFile() {
  local output=$(shasum -a 256 $1)
  echo "${output%% *}"
}

##
# Generate HMAC signature using SHA256
# Arguments:
#   $1 signing key in hex
#   $2 string data to sign
# Returns:
#   string signature
##
hmac_sha256() {
  printf "$2" | openssl dgst -binary -hex -sha256 -mac HMAC -macopt hexkey:$1 \
              | sed 's/^.* //'
}

##
# Sign data using AWS Signature Version 4
# Arguments:
#   $1 AWS Secret Access Key
#   $2 yyyymmdd
#   $3 AWS Region
#   $4 AWS Service
#   $5 string data to sign
# Returns:
#   signature
##
sign() {
  local kSigning=$(hmac_sha256 $(hmac_sha256 $(hmac_sha256 \
                 $(hmac_sha256 $(hex256 "AWS4$1") $2) $3) $4) "aws4_request")
  hmac_sha256 "${kSigning}" "$5"
}

##
# Get endpoint of specified region
# Arguments:
#   $1 region
# Returns:
#   amazon andpoint
##
convS3RegionToEndpoint() {
  case "$1" in
    us-east-1) echo "s3.amazonaws.com"
      ;;
    *) echo s3-${1}.amazonaws.com
      ;;
    esac
}

##
# Perform request to S3
# Uses the following Globals:
#   METHOD                string
#   AWS_ACCESS_KEY_ID     string
#   AWS_SECRET_ACCESS_KEY string
#   AWS_REGION            string
#   RESOURCE_PATH         string
#   FILE_TO_UPLOAD        string
#   CONTENT_TYPE          string
#   PUBLISH               bool
#   DEBUG                 bool
#   VERBOSE               bool
#   INSECURE              bool
#   SILENT                bool
##
performRequest() {
  local timestamp=$(date -u "+%Y-%m-%d %H:%M:%S")
  local isoTimestamp=$(date -ud "${timestamp}" "+%Y%m%dT%H%M%SZ")
  local dateScope=$(date -ud "${timestamp}" "+%Y%m%d")
  local host=$(convS3RegionToEndpoint "${AWS_REGION}")

  # Generate payload hash
  if [[ $METHOD == "PUT" ]]; then
    local payloadHash=$(sha256HashFile $FILE_TO_UPLOAD)
  else
    local payloadHash=$(sha256Hash "")
  fi

  local cmd=("curl")
  local headers=
  local headerList=

  if [[ ${DEBUG} != true ]]; then
    cmd+=("--fail")
  fi

  if [[ ${VERBOSE} == true ]]; then
    cmd+=("--verbose")
  fi

  if [[ ${SILENT} == true ]]; then
    cmd+=("--silent")
  fi

  if [[ ${METHOD} == "PUT" ]]; then
    cmd+=("-T" "${FILE_TO_UPLOAD}")
  fi
  cmd+=("-X" "${METHOD}")

  if [[ ${METHOD} == "PUT" && ! -z "${CONTENT_TYPE}" ]]; then
    cmd+=("-H" "Content-Type: ${CONTENT_TYPE}")
    headers+="content-type:${CONTENT_TYPE}\n"
    headerList+="content-type;"
  fi

  cmd+=("-H" "Host: ${host}")
  headers+="host:${host}\n"
  headerList+="host;"

  if [[ ${METHOD} == "PUT" && "${PUBLISH}" == true ]]; then
    cmd+=("-H" "x-amz-acl: public-read")
    headers+="x-amz-acl:public-read\n"
    headerList+="x-amz-acl;"
  fi

  cmd+=("-H" "x-amz-content-sha256: ${payloadHash}")
  headers+="x-amz-content-sha256:${payloadHash}\n"
  headerList+="x-amz-content-sha256;"

  cmd+=("-H" "x-amz-date: ${isoTimestamp}")
  headers+="x-amz-date:${isoTimestamp}"
  headerList+="x-amz-date"

  # Generate canonical request
  local canonicalRequest="${METHOD}
${RESOURCE_PATH}

${headers}

${headerList}
${payloadHash}"

  # Generated request hash
  local hashedRequest=$(sha256Hash "${canonicalRequest}")

  # Generate signing data
  local stringToSign="AWS4-HMAC-SHA256
${isoTimestamp}
${dateScope}/${AWS_REGION}/s3/aws4_request
${hashedRequest}"

  # Sign data
  local signature=$(sign "${AWS_SECRET_ACCESS_KEY}" "${dateScope}" "${AWS_REGION}" \
                   "s3" "${stringToSign}")

  local authorizationHeader="AWS4-HMAC-SHA256 Credential=${AWS_ACCESS_KEY_ID}/${dateScope}/${AWS_REGION}/s3/aws4_request, SignedHeaders=${headerList}, Signature=${signature}"
  cmd+=("-H" "Authorization: ${authorizationHeader}")

  local protocol="https"
  if [[ $INSECURE == false ]]; then
    protocol="http"
  fi
  cmd+=("${protocol}://${host}${RESOURCE_PATH}")

  # Curl
  "${cmd[@]}"
}

