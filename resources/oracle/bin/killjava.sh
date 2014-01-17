#!/usr/bin/env bash
# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
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

# Kill script for use as the parameter of OpenJDK's -XX:OnOutOfMemoryError

COMMAND='pkill -9 -f .*-XX:OnOutOfMemoryError=.*killjava.*'
LOG_FILE="$PWD/.out-of-memory.log"

function log {
  echo "$(date +%FT%T.%2N%z) FATAL $1" >> $LOG_FILE
}

log "Attempting to kill Java processes using '$COMMAND'"
log "Processes Before:
$(ps -ef)
"

$($COMMAND)

log "Processes After:
$(ps -ef)
"
