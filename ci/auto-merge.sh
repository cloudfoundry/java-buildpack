#!/usr/bin/env bash

set -e

pushd upstream
  COMMIT=$(git rev-parse HEAD)
popd

git clone downstream merged

pushd merged
  git config --local user.name "Spring Buildmaster"
  git config --local user.email "buildmaster@springframework.org"

  git remote add upstream ../upstream
  git fetch upstream

  git merge --no-ff --log --no-edit $COMMIT
popd
