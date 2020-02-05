#!/usr/bin/env bash
# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
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

set -euo pipefail

pushd upstream
  COMMIT=$(git rev-parse HEAD)
popd

git clone downstream merged

pushd merged
  git config --local user.name "$GIT_USER_NAME"
  git config --local user.email $GIT_USER_EMAIL

  git remote add upstream ../upstream
  git fetch upstream --no-tags

  git merge --no-ff --log --no-edit $COMMIT
popd
