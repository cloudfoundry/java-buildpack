#!/usr/bin/env bash
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.
#
# Upload a file to S3
# (c) Michele Mancioppi <michele.mancioppi@sap.com>

set -eu

readonly SCRIPT_FOLDER=$(dirname $0)
# Check the first argument (heap dump filename) has been provided
readonly FILE_TO_UPLOAD="${1:?}"
readonly TARGET_FILE=$(basename ${FILE_TO_UPLOAD})

# Default, to be overwritten via the config file
KEEP_IN_CONTAINER=true

CLEANUP() {
  if [ "${KEEP_IN_CONTAINER}" = false ]; then
    if [ -e "${FILE_TO_UPLOAD}" ]; then
      rm -f "${FILE_TO_UPLOAD}"

      if [ "${LOG}" = true ]; then
        echo "Heap dump '${FILE_TO_UPLOAD}' removed from the container"
      fi
    fi
  fi
}
trap CLEANUP EXIT

if [ ! -e "${FILE_TO_UPLOAD}" ]; then
  (>&2 echo "Heap dump file '${FILE_TO_UPLOAD}' not found in container")
  exit 1
fi

CONFIG='s3.config'

# Source and check vars exist
. "${SCRIPT_FOLDER}/../${CONFIG}"

# Validate all required configs have been provided
BUCKET="${BUCKET:?}"
AWS_ACCESS_KEY="${AWS_ACCESS_KEY:?}"
AWS_SECRET_KEY="${AWS_SECRET_KEY:?}"
AWS_REGION="${AWS_REGION:?}"
LOG="${LOG:?}"
KEEP_IN_CONTAINER="${KEEP_IN_CONTAINER:?}"

if [ "${LOG}" = true ]; then
  echo "Uploading heap dump '${FILE_TO_UPLOAD}' to S3 bucket '${BUCKET}'"
fi

COMMAND_OUTPUT=$(AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY}" AWS_SECRET_ACCESS_KEY="${AWS_SECRET_KEY}" AWS_DEFAULT_REGION="${AWS_REGION}" ${SCRIPT_FOLDER}/s3-put \
  --silent -c 'application/x-octet-stream' -T "${FILE_TO_UPLOAD}" "/${BUCKET}/${TARGET_FILE}")

if [ "${LOG}" = true ]; then
  echo "Heap dump '${FILE_TO_UPLOAD}' uploaded to S3 bucket '${BUCKET}'"
fi